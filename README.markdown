# Omniship

[![build-status](https://app.wercker.com/status/d331d9c12c15c6a20ddf774724247270/s/master "wercker status")](https://app.wercker.com/magma/omniship/runs?view=runs&q=branch:master)

[![coverage-status](https://coveralls.io/repos/github/magma-labs/omniship/badge.svg)](https://coveralls.io/github/magma-labs/omniship)

A fork of Digi-Cazter/omniship:

> This library has been created to make web requests to common shipping carriers using XML.  I created this to be easy to use with a nice Ruby API.  This code was originally forked from the *Shopify/active_shipping* code, I began to strip it down cause I wan't a cleaner API along with the ability to actually create shipment labels with it.  After changing enough code, I created this gem as its own project since it's different enough.


## Supported Shipping Carriers

* [UPS](http://www.ups.com) (Stable)
  - Create Shipment
  - Void Shipment
  - Get Rates
  - Validate Address
  - Validate Address with Street
* [FedEx](http://www.fedex.com) (Unverified)
  - Create Shipment
  - Void Shipment
  - Get Rates
  - Shipment Tracking
* [USPS](http://www.usps.com) COMING SOON!

## Simple example snippets
### UPS Code Example ###
To run in test mode during development, pass :test => true as an option
into create_shipment and accept_shipment.

      def create_shipment
      # If you have created the omniship.yml config file
      @config  = OMNISHIP_CONFIG[Rails.env]['ups']
      shipment = create_ups_shipment
    end

    def create_ups_shipment
      # If using the yml config
      ups = Omniship::UPS.new
      # Else just pass in the credentials
      ups = Omniship::UPS.new(:login => @user, :password => @password, :key => @key)
      send_options = {}
      send_options[:origin_account] = @config["account"] # Or just put the shipper account here
      send_options[:service]        = "03"
      response = ups.create_shipment(origin, destination, package, options = send_options)
      return ups.accept_shipment(response)
    end

    def origin
      address = {}
      address[:name]     = "My House"
      address[:address1] = "555 Diagonal"
      address[:city]     = "Saint George"
      address[:state]    = "UT"
      address[:zip]      = "84770"
      address[:country]  = "USA"
      return Omniship::Address.new(address)
    end

    def destination
      address = {}
      address[:company_name] = "Wal-Mart"
      address[:address1]     = "555 Diagonal"
      address[:city]         = "Saint George"
      address[:state]        = "UT"
      address[:zip]          = "84770"
      address[:country]      = "USA"
      return Omniship::Address.new(address)
    end

    def packages
      # UPS can handle a single package or multiple packages
      pkg_list = []
      weight = 1
      length = 1
      width  = 1
      height = 1
      package_type = "02"
      pkg_list << Omniship::Package.new(weight.to_i,[length.to_i,width.to_i,height.to_i],:units => :imperial, :package_type => package_type)
      return pkg_list
    end


## License

Unless otherwise noted in specific files, all code in the Omniship project is under the copyright and license described in the included MIT-LICENSE file.
