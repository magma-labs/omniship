require 'test_helper'

class FedExTest < Minitest::Test
  def setup
    @packages               = TestFixtures.packages
    @locations              = TestFixtures.locations
    @carrier                = FedEx.new(:key => '1111', :password => '2222', :account => '3333', :login => '4444')
  end

  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response'))
    assert_instance_of Omniship::TrackingResponse, @carrier.find_tracking_info('077973360403984', :test => true)
  end

  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response'))
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal 6, response.shipment_events.size
  end

  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response'))
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end

  def test_building_request_and_parsing_response
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( @locations[:ottawa],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:book, :wii), :test => true)
    assert_equal ["FedEx Ground"], response.rates.map(&:service_name)
    assert_equal [38.36], response.rates.map(&:price)

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates

    rate = response.rates.first
    assert_equal 'FedEx', rate.carrier
    assert_equal 'CAD', rate.currency
    assert_instance_of Float, rate.total_price
    assert_instance_of Float, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end

  def test_service_name_for_code
    FedEx::ServiceTypes.each do |capitalized_name, readable_name|
      assert_equal readable_name, FedEx.service_name_for_code(capitalized_name)
    end
  end

  def test_service_name_for_code_handles_yet_unknown_codes
    assert_equal "FedEx Express Saver Saturday Delivery", FedEx.service_name_for_code('FEDEX_EXPRESS_SAVER_SATURDAY_DELIVERY')
    assert_equal "FedEx Some Weird Rate", FedEx.service_name_for_code('SOME_WEIRD_RATE')
  end

  #TODO: Fix fixtures with bad
  def test_returns_gbp_instead_of_ukl_currency_for_uk_rates
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('CAD', 'UKL')

    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( @locations[:ottawa],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:book, :wii), :test => true)
    assert_equal ["FedEx Ground"], response.rates.map(&:service_name)
    assert_equal [38.36], response.rates.map(&:price)

    assert response.success?, response.message

    response.rates.each do |rate|
      assert_equal 'FedEx', rate.carrier
      assert_equal 'GBP', rate.currency
    end
  end

  def test_delivery_range_based_on_delivery_date
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('CAD', 'UKL')
    @carrier.expects(:commit).returns(mock_response)
    rate_estimates = @carrier.find_rates( @locations[:ottawa],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:book, :wii), :test => true)

    assert_equal 'FIVE_DAYS', rate_estimates.rates[0].delivery_date
  end
end
