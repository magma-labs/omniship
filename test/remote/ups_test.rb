require 'test_helper'

class UPSTest < Minitest::Test

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = UPS.new(fixtures(:ups).merge(:test => true))
  end

  def test_just_country_given
    response = @carrier.find_rates(
                 @locations[:beverly_hills],
                 Address.new(:country => 'CA'),
                 Package.new(100, [5,10,20])
               )
    assert_not_equal [], response.rates
  end

  def test_ottawa_to_beverly_hills
    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:beverly_hills],
                 @packages.values_at(:book, :wii),
                 :test => true
               )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

    rate = response.rates.first
    assert_equal 'UPS', rate.carrier
    assert_equal 'CAD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end


  def test_us_to_uk_with_different_pickup_types
    daily_response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:london],
      @packages.values_at(:book, :wii),
      :pickup_type => :daily_pickup,
      :test => true
    )
    one_time_response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:london],
      @packages.values_at(:book, :wii),
      :pickup_type => :one_time_pickup,
      :test => true
    )
    assert_not_equal daily_response.rates.map(&:price), one_time_response.rates.map(&:price)
  end

  def test_bare_packages
    p = Package.new(0,[0])
    response = @carrier.find_rates(
                 @locations[:beverly_hills], # imperial (U.S. origin)
                 @locations[:ottawa],
                 p,
                 :test => true
               )
    assert response.success?, response.message

    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:beverly_hills], # metric
                 p,
                 :test => true
               )
    assert response.success?, response.message
  end

  def test_different_rates_based_on_address_type
    responses = {}
    locations = [
      :fake_home_as_residential, :fake_home_as_commercial,
      :fake_google_as_residential, :fake_google_as_commercial
      ]

    locations.each do |location|
      responses[location] = @carrier.find_rates(
                              @locations[:beverly_hills],
                              @locations[location],
                              @packages.values_at(:chocolate_stuff)
                            )
    end

    prices_of = lambda {|sym| responses[sym].rates.map(&:price)}

    assert_not_equal prices_of.call(:fake_home_as_residential), prices_of.call(:fake_home_as_commercial)
    assert_not_equal prices_of.call(:fake_google_as_commercial), prices_of.call(:fake_google_as_residential)
  end
end
