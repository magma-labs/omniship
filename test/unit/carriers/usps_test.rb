require 'test_helper'

class USPSTest < Minitest::Test

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = USPS.new(:login => 'login')
  end

  def test_size_codes
    assert_equal 'REGULAR', USPS.size_code_for(Package.new(2, [1,12,1], :units => :imperial))
    assert_equal 'LARGE', USPS.size_code_for(Package.new(2, [1,1,12.1], :units => :imperial))
    assert_equal 'LARGE', USPS.size_code_for(Package.new(2, [1000,1000,1000], :units => :imperial))
  end


  def test_parse_max_dimension_sentences
    limits = {
      "Max. length 46\", width 35\", height 46\" and max. length plus girth 108\"" =>
        [{:length => 46.0, :width => 46.0, :height => 35.0, :length_plus_girth => 108.0}],
      "Max.length 42\", max. length plus girth 79\"" =>
        [{:length => 42.0, :length_plus_girth => 79.0}],
      "9 1/2\" X 12 1/2\"" =>
        [{:length => 12.5, :width => 9.5, :height => 0.75}, "Flat Rate Envelope"],
      "Maximum length and girth combined 108\"" =>
        [{:length_plus_girth => 108.0}],
      "USPS-supplied Priority Mail flat-rate envelope 9 1/2\" x 12 1/2.\" Maximum weight 4 pounds." =>
        [{:length => 12.5, :width => 9.5, :height => 0.75}, "Flat Rate Envelope"],
      "Max. length 24\", Max. length, height, depth combined 36\"" =>
        [{:length => 24.0, :length_plus_width_plus_height => 36.0}]
    }
    p = @packages[:book]
    limits.each do |sentence,hashes|
      dimensions = hashes[0].update(:weight => 50.0)
      service_node = build_service_node(
        :name => hashes[1],
        :max_weight => 50,
        :max_dimensions => sentence )
      @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions)
      @carrier.send(:package_valid_for_service, p, service_node)
    end

    service_node = build_service_node(
        :name => "flat-rate box",
        :max_weight => 50,
        :max_dimensions => "USPS-supplied Priority Mail flat-rate box. Maximum weight 20 pounds." )

    # should test against either kind of flat rate box:
    dimensions = [{:weight => 50.0, :length => 11.0, :width => 8.5, :height => 5.5}, # or...
      {:weight => 50.0, :length => 13.625, :width => 11.875, :height => 3.375}]
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[0])
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[1])
    @carrier.send(:package_valid_for_service, p, service_node)

  end

  def test_package_valid_for_max_dimensions
    weight_in_ounces = 70 * 16
    p = Package.new(weight_in_ounces, [10,10,10], :units => :imperial)
    limits = {:weight => 70.0, :length => 10.0, :width => 10.0, :height => 10.0, :length_plus_girth => 50.0, :length_plus_width_plus_height => 30.0}
    assert_equal true, @carrier.send(:package_valid_for_max_dimensions, p, limits)

    limits.keys.each do |key|
      dimensions = {key => (limits[key] - 1)}
      assert_equal false, @carrier.send(:package_valid_for_max_dimensions, p, dimensions)
    end

  end

  def test_strip_9_digit_zip_codes
    request = URI.decode(@carrier.send(:build_us_rate_request, @packages[:book], "90210-1234", "123456789"))
    assert !(request =~ /\>90210-1234\</)
    assert request =~ /\>90210\</
    assert !(request =~ /\>123456789\</)
    assert request =~ /\>12345\</
  end

  def test_maximum_weight
    weight_in_ounces = 70 * 16
    assert Package.new(weight_in_ounces, [5,5,5], :units => :imperial).mass == @carrier.maximum_weight
    assert Package.new(weight_in_ounces + 0.01, [5,5,5], :units => :imperial).mass > @carrier.maximum_weight
    assert Package.new(weight_in_ounces - 0.01, [5,5,5], :units => :imperial).mass < @carrier.maximum_weight
  end

  def test_updated_domestic_rate_name_format_with_unescaped_html
    mock_response = xml_fixture('usps/beverly_hills_to_new_york_book_rate_response')
    @carrier.expects(:commit).returns(mock_response)
    rates_response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:new_york],
      @packages[:book],
      :test => true
    )
    rate_names = [
      'USPS Express Mail',
      'USPS Express Mail Flat Rate Envelope',
      'USPS Express Mail Flat Rate Envelope Hold For Pickup',
      'USPS Express Mail Hold For Pickup',
      'USPS Express Mail Legal Flat Rate Envelope',
      'USPS Express Mail Legal Flat Rate Envelope Hold For Pickup',
      'USPS Express Mail Sunday/Holiday Delivery',
      'USPS Express Mail Sunday/Holiday Delivery Flat Rate Envelope',
      'USPS Express Mail Sunday/Holiday Delivery Legal Flat Rate Envelope',
      'USPS First-Class Mail Large Envelope',
      'USPS First-Class Mail Package',
      'USPS Library Mail',
      'USPS Media Mail',
      'USPS Parcel Post',
      'USPS Priority Mail',
      'USPS Priority Mail Flat Rate Envelope',
      'USPS Priority Mail Gift Card Flat Rate Envelope',
      'USPS Priority Mail Large Flat Rate Box',
      'USPS Priority Mail Legal Flat Rate Envelope',
      'USPS Priority Mail Medium Flat Rate Box',
      'USPS Priority Mail Padded Flat Rate Envelope',
      'USPS Priority Mail Small Flat Rate Box',
      'USPS Priority Mail Small Flat Rate Envelope',
      'USPS Priority Mail Window Flat Rate Envelope'
    ]
    assert_equal rate_names, rates_response.rates.collect(&:service_name).sort
  end

  private

  def build_service_node(options = {})
    XmlNode.new('Service') do |service_node|
      service_node << XmlNode.new('Pounds', options[:pounds] || "0")
      service_node << XmlNode.new('SvcCommitments', options[:svc_commitments] || "Varies")
      service_node << XmlNode.new('Country', options[:country] || "CANADA")
      service_node << XmlNode.new('ID', options[:id] || "3")
      service_node << XmlNode.new('MaxWeight', options[:max_weight] || "64")
      service_node << XmlNode.new('SvcDescription', options[:name] || "First-Class Mail International")
      service_node << XmlNode.new('MailType', options[:mail_type] || "Package")
      service_node << XmlNode.new('Postage', options[:postage] || "3.76")
      service_node << XmlNode.new('Ounces', options[:ounces] || "9")
      service_node << XmlNode.new('MaxDimensions', options[:max_dimensions].dup || "Max. length 24\", Max. length, height, depth combined 36\"")
    end.to_xml_element
  end

  def build_service_hash(options = {})
    {"Pounds"=> options[:pounds] || "0",
         "SvcCommitments"=> options[:svc_commitments] || "Varies",
         "Country"=> options[:country] || "CANADA",
         "ID"=> options[:id] || "3",
         "MaxWeight"=> options[:max_weight] || "64",
         "SvcDescription"=> options[:name] || "First-Class Mail International",
         "MailType"=> options[:mail_type] || "Package",
         "Postage"=> options[:postage] || "3.76",
         "Ounces"=> options[:ounces] || "9",
         "MaxDimensions"=> options[:max_dimensions] ||
          "Max. length 24\", Max. length, height, depth combined 36\""}
  end
end
