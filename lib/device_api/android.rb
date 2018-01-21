require 'device_api/android/adb'
require 'device_api/android/device'
require 'device_api/android/signing'

# Load plugins
require 'device_api/android/plugins/audio'
require 'device_api/android/plugins/memory'
require 'device_api/android/plugins/battery'
require 'device_api/android/plugins/disk'

# Load additional device types
require 'device_api/android/devices/kindle'
require 'device_api/android/devices/samsung'

module DeviceAPI
  module Android
    # Returns array of connected android devices
    def self.devices
      ADB.devices.map do |d|
        next unless d.keys.first && !d.keys.first.include?('?')
        qualifier = d.keys.first
        remote = check_if_remote_device?(qualifier)
        DeviceAPI::Android::Device.create(get_device_type(d), qualifier: qualifier, state: d.values.first, remote: remote)
      end.compact
    end

    # Retrieve an Device object by serial id
    def self.device(qualifier)
      if qualifier.to_s.empty?
        raise DeviceAPI::BadSerialString, "Qualifier was '#{qualifier.nil? ? 'nil' : qualifier}'"
      end
      device = ADB.devices.select { |k| k.keys.first == qualifier }
      state = device.first[qualifier] || 'unknown'
      remote = check_if_remote_device?(qualifier)
      DeviceAPI::Android::Device.create(get_device_type(:"#{qualifier}" => state), qualifier: qualifier, state: state, remote: remote)
    end

    def self.connect(ipaddress, port = 5555)
      ADB.connect(ipaddress, port)
    end

    def self.disconnect(ipaddress, port = 5555)
      ADB.disconnect(ipaddress, port)
    end

    def self.check_if_remote_device?(qualifier)
      ADB.check_ip_address(qualifier)
      true
    rescue ADBCommandError
      false
    end

    # Return the device type used in determining which Device Object to create
    def self.get_device_type(options)
      return :default if %w[unauthorized offline unknown].include? options.values.first
      qualifier = options.keys.first
      state = options.values.first
      begin
        man = Device.new(qualifier: qualifier, state: state).manufacturer
      rescue DeviceAPI::DeviceNotFound
        return :default
      rescue StandardError => e
        puts "Unrecognised exception whilst finding device '#{qualifier}' (state: #{state})"
        puts e.message
        puts e.backtrace.inspect
        return :default
      end
      return :default if man.nil?
      type = case man.downcase
             when 'amazon'
               :kindle
             when 'samsung'
               :samsung
             else
               :default
             end
      type
    end

    # Serial error class
    class BadSerialString < StandardError
    end
  end
end
