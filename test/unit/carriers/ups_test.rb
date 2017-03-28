require_relative '../../test_helper'

class UPSTest < Minitest::Test

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations

    @carrier   = UPS.new(
      origin_account: ENV["UPS_ACCOUNT"],
      key:            ENV["UPS_KEY"],
      login:          ENV["UPS_USERNAME"],
      password:       ENV["UPS_PASSWORD"],
      test:           true,
      logger:         ::Logger.new("/dev/null")
    )

    @tracking_response = xml_fixture('ups/shipment_from_tiger_direct')
  end

  def test_tracking_info
    response = VCR.use_cassette :ups_find_tracking_info do
      @carrier.find_tracking_info("1Z1234eE0291980793")
    end

    assert_equal response["TrackResponse"]["Response"]["ResponseStatusDescription"], "Success"
  end

  # TODO: Figure out what's this test about
  def test_response_parsing
    skip "Figure out what's this test about"
    #mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
    #@carrier.expects(:commit).returns(mock_response)
    #response = @carrier.find_rates( @locations[:beverly_hills],
                                    #@locations[:real_home_as_residential],
                                    #@packages.values_at(:chocolate_stuff))
    #assert_equal [ "UPS Ground",
                   #"UPS Three-Day Select",
                   #"UPS Second Day Air",
                   #"UPS Next Day Air Saver",
                   #"UPS Next Day Air Early A.M.",
                   #"UPS Next Day Air"], response.rates.map(&:service_name)
    #assert_equal [9.92, 21.91, 30.07, 55.09, 94.01, 61.24], response.rates.map(&:price)

    #date_test = [nil, 3, 2, 1, 1, 1].map do |days|
      #DateTime.strptime(days.days.from_now.strftime("%Y-%m-%d"), "%Y-%m-%d") if days
    #end

    #assert_equal date_test, response.rates.map(&:delivery_date)
  end

  def test_create_shipment
    response = VCR.use_cassette :ups_create_shipment do
      @carrier.create_shipment(
        @locations[:sender_address],
        @locations[:cakestyle_address],
        @packages.values_at(:box),
        {:service => '03'}
      )
    end

    assert_equal "Success", response[:status]
    assert response[:digest].present?
  end

  def test_void_shipment
    response = VCR.use_cassette :ups_void_shipment do
      @carrier.void_shipment("", ["1ZISDE016691676846"])
    end

    assert_equal "Success", response[:status_type_description]
    assert_equal "Voided", response[:status_code_description].text
  end

  # TODO: Improve test assertion, previous was inaccurate, current is too generic
  def test_validate_address
     response = VCR.use_cassette :ups_validate_address do
       @carrier.validate_address('BEVERLY HILLS','CA','90210','US')
     end

    assert_equal response.class , Hash
  end

  # TODO: Improve test assertion, previous was inaccurate, current is too generic
  def test_validate_address_street
     response = VCR.use_cassette :ups_validate_address_street do
       @carrier.validate_address_street('455 N REXFORD DR','BEVERLY HILLS','CA','90210','US')
     end

     assert_equal response.class, Array
  end

end
