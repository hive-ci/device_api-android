require 'device_api/device'
require 'device_api/android/adb'
require 'device_api/android/aapt'
require 'device_api/android/device_model'

# DeviceAPI - an interface to allow for automation of devices
module DeviceAPI
  # Android component of DeviceAPI
  module Android
    # Device class used for containing the accessors of the physical device information
    class Device < DeviceAPI::Device
      attr_reader :qualifier

      @@subclasses = {}

      # Called by any inheritors to register themselves with the parent class
      def self.inherited(klass)
        key = /::([^:]+)$/.match(klass.to_s.downcase)[1].to_sym
        @@subclasses[key] = klass
      end

      # Returns an object of the specified type, if it exists. Defaults to returning self
      def self.create(type, options = {})
        return @@subclasses[type.to_sym].new(options) if @@subclasses[type.to_sym]
        new(options)
      end

      def initialize(options = {})
        # For devices connected with USB, qualifier and serial are same
        @qualifier = options[:qualifier]
        @state     = options[:state]
        @serial    = options[:serial] || @qualifier
        @remote    = options[:remote] ? true : false

        return unless is_remote?

        set_ip_and_port
        @serial = serial_no unless %w[unknown offline].include? @state
      end

      def set_ip_and_port
        address = @qualifier.split(':')
        @ip_address = address.first
        @port = address.last
      end

      def is_remote?
        @remote || false
      end

      # Mapping of device status - used to provide a consistent status across platforms
      # @return (String) common status string
      def status
        {
          'device'         => :ok,
          'no device'      => :dead,
          'offline'        => :offline,
          'unauthorized'   => :unauthorized,
          'no permissions' => :no_permissions,
          'unknown'        => :unknown
        }[@state]
      end

      def connect
        ADB.connect(@ip_address, @port)
      end

      def disconnect
        unless is_remote?
          raise DeviceAPI::Android::DeviceDisconnectedWhenNotARemoteDevice, "Asked to disconnect device #{qualifier} when it is not a remote device"
        end
        ADB.disconnect(@ip_address, @port)
      end

      # Return whether device is connected or not
      def is_connected?
        ADB.devices.any? { |device| device.include? qualifier }
      end

      # Return the device range
      # @return (String) device range string
      def range
        device = self.device
        model  = self.model

        return device if device == model
        "#{device}_#{model}"
      end

      # Return the serial number of device
      # @return (String) serial number
      def serial_no
        get_prop('ro.serialno')
      end

      # Return the device class - i.e. tablet, phone, etc
      # @return (String) Android device class
      def device_class
        get_prop('ro.build.characteristics')
      end

      # Return the device type
      # @return (String) device type string
      def device
        get_prop('ro.product.device')
      end

      # Returns either the device marketing name or manufacturer model
      # Example: Galaxy S6 or SM-G920V
      # @return (String) device model string
      def model
        DeviceModel.search(manufacturer, manufacturer_model)
      end

      # Return the device model name used by the manufacturer
      # @return (String) device model string
      def manufacturer_model
        get_prop('ro.product.model')
      end

      # Return the device manufacturer
      # @return (String) device manufacturer string
      def manufacturer
        get_prop('ro.product.manufacturer')
      end

      # Return the Android OS version
      # @return (String) device Android version
      def version
        get_prop('ro.build.version.release')
      end

      # Return the Android OS name
      # @return (String) Android  OS name
      def os_name
        os_version_number = version.to_f

        case os_version_number
        when 1.5       then 'Cupcake'
        when 1.6       then 'Donut'
        when 2.0..2.1  then 'Eclair'
        when 2.2       then 'Froyo'
        when 2.3       then 'Gingerbread'
        when 3.0..3.2  then 'Honeycomb'
        when 4.0       then 'Ice Cream Sandwich'
        when 4.1..4.3  then 'Jelly Bean'
        when 4.4       then 'KitKat'
        when 5.0..5.1  then 'Lollipop'
        when 6.0       then 'Marshmallow'
        when 7.0..7.1  then 'Nougat'
        when 8.0..8.1  then 'Oreo'
        else 'Unknown'
        end
      end

      # Return the battery level
      # @return (String) device battery level
      def battery_level
        get_battery_info.level
      end

      # Is the device currently being powered?
      # @return (Boolean) true if it is being powered in some way, false if it is unpowered
      def powered?
        get_battery_info.powered
      end

      def block_package(package)
        if version < '5.0.0'
          ADB.block_package(qualifier, package)
        else
          ADB.hide_package(qualifier, package)
        end
      end

      # Return the device orientation
      # @return (String) current device orientation
      def orientation
        res = get_dumpsys('SurfaceOrientation')

        case res
        when '0', '2'
          :portrait
        when '1', '3'
          :landscape
        when nil
          raise StandardError, 'No output returned is there a device connected?', caller
        else
          raise StandardError, "Device orientation not returned got: #{res}.", caller
        end
      end

      # Install a specified apk
      # @param [String] apk string containing path to the apk to install
      # @return [Symbol, Exception] :success when the apk installed successfully, otherwise an error is raised
      def install(apk)
        raise StandardError, 'No apk specified.', caller if apk.empty?
        res = install_apk(apk)

        case res
        when 'Success'
          :success
        else
          raise StandardError, res, caller
        end
      end

      # Uninstall a specified package
      # @param [String] package_name name of the package to uninstall
      # @return [Symbol, Exception] :success when the package is removed, otherwise an error is raised
      def uninstall(package_name)
        res = uninstall_apk(package_name)
        case res
        when 'Success'
          :success
        else
          raise StandardError, "Unable to install 'package_name' Error Reported: #{res}", caller
        end
      end

      # Return the package name for a specified apk
      # @param [String] apk string containing path to the apk
      # @return [String, Exception] package name if it can be found, otherwise an error is raised
      def package_name(apk)
        @apk = apk
        result = get_app_props('package')['name']
        raise StandardError, 'Package name not found', caller if result.nil?
        result
      end

      def list_installed_packages
        packages = ADB.pm(qualifier, 'list packages')
        packages.split("\r\n")
      end

      # Return the app version number for a specified apk
      # @param [String] apk string containing path to the apk
      # @return [String, Exception] app version number if it can be found, otherwise an error is raised
      def app_version_number(apk)
        @apk = apk
        result = get_app_props('package')['versionName']
        raise StandardError, 'Version number not found', caller if result.nil?
        result
      end

      # Initiate monkey tests
      # @param [Hash] args arguments to pass on to ADB.monkey
      def monkey(args)
        ADB.monkey(qualifier, args)
      end

      # Capture screenshot on device
      # @param [Hash] args arguments to pass on to ADB.screencap
      def screenshot(args)
        ADB.screencap(qualifier, args)
      end

      # Get the IMEI number of the device
      # @return (String) IMEI number of current device
      def imei
        get_phoneinfo['Device ID']
      end

      # Get the memory information for the current device
      # @return [DeviceAPI::Android::Plugins::Memory] the memory plugin containing relevant information
      def memory
        get_memory_info
      end

      def battery
        get_battery_info
      end

      # Check if the devices screen is currently turned on
      # @return [Boolean] true if the screen is on, otherwise false
      def screen_on?
        is_screen_on  = get_powerinfo('mScreenOn').casecmp('true').zero?
        is_display_on = get_powerinfo('Display Power: state').casecmp('on').zero?

        is_screen_on || is_display_on ? true : false
      end

      # Check if the devices screen is unlocked
      # @return [Boolean] true if the screen is unlocked, otherwise false
      def screen_unlocked?
        wake_lock     = get_powerinfo('mHoldingWakeLockSuspendBlocker').casecmp('true').zero?
        display_lock  = get_powerinfo('mHoldingDisplaySuspendBlocker').casecmp('true').zero?
        user_activity = get_powerinfo('mUserActivityTimeoutOverrideFromWindowManager') == '-1'

        screen_on? && wake_lock && display_lock && user_activity ? true : false
      end

      # Lock the device
      def lock
        ADB.keyevent(qualifier, '6') if screen_on?
      end

      # Unlock the device by sending a wakeup command
      def unlock
        # This is used to unlock the device if its password protected, if the
        # variable is not set then it will just try swipe to unlock
        @device_pin = ENV['DEVICE_PIN'].to_s

        ADB.keyevent(qualifier, '26') unless screen_on?
        ADB.swipe(qualifier, swipe_coords) unless screen_unlocked?

        return if @device_pin.empty?

        ADB.text(qualifier, @device_pin) unless screen_unlocked?
        ADB.keyevent(qualifier, '66') unless screen_unlocked?
      end

      # Return the DPI of the attached device
      # @return [String] DPI of attached device
      def dpi
        get_dpi(qualifier)
      end

      # Return the device type based on the DPI
      # @return [Symbol] :tablet or :mobile based upon the devices DPI
      def type
        device_class.casecmp('tablet').zero? ? :tablet : :mobile
      end

      # Returns wifi status and access point name
      # @return [Hash] :status and :access_point
      def wifi_status
        ADB.wifi(qualifier)
      end

      def battery_info
        ADB.get_battery_info(qualifier)
      end

      # @param [String] command to start the intent
      # Return the stdout of executed intent
      # @return [String] stdout
      def intent(command)
        ADB.am(qualifier, command)
      end

      # Reboots the device
      def reboot
        ADB.reboot(qualifier, is_remote?)
      end

      # Returns disk status
      # @return [Hash] containing disk statistics
      def diskstat
        get_disk_info
      end

      # Returns the device uptime
      def uptime
        ADB.get_uptime(qualifier)
      end

      # Returns the Wifi IP address
      def ip_address
        interface = ADB.get_network_interface(qualifier, 'wlan0')
        if interface =~ /ip (.*) mask/
          Regexp.last_match[1]
        elsif interface =~ /inet addr:(.*)\s+Bcast/
          Regexp.last_match[1].strip
        end
      end

      # Returns the Wifi mac address
      def wifi_mac_address
        ADB.get_wifi_mac_address(qualifier)
      end

      def resolution
        res = ADB.dumpsys(qualifier, 'window | grep mUnrestrictedScreen')
        size = /^.* (.*)x(.*)$/.match(res.first)
        [size[1], size[2]].map(&:to_i)
      end

      private

      def swipe_coords
        x, y = resolution

        if version.split('.').first.to_i < 5
          { x_from: x - 100, y_from: y / 2, x_to: x / 6, y_to: y / 2 }
        else
          { x_from: x / 2, y_from: y - 100, x_to: x / 2, y_to: y / 6 }
        end
      end

      def get_network_info
        ADB.get_network_info(qualifier)
      end

      def get_disk_info
        @diskstat ||= DeviceAPI::Android::Plugin::Disk.new(qualifier: qualifier)
        @diskstat.process_stats
      end

      def get_battery_info
        @battery ||= DeviceAPI::Android::Plugin::Battery.new(qualifier: qualifier)
        @battery
      end

      def get_memory_info
        @memory ||= DeviceAPI::Android::Plugin::Memory.new(qualifier: qualifier)
        @memory
      end

      def get_app_props(key)
        @app_props ||= AAPT.get_app_props(@apk)
        @app_props.each { |x| break x[key] }
      end

      def get_prop(key)
        @props = ADB.getprop(qualifier) if !@props || !@props[key]
        @props[key].to_s
      end

      def get_dumpsys(key)
        @props = ADB.getdumpsys(qualifier)
        @props[key]
      end

      def get_powerinfo(key)
        @props = ADB.getpowerinfo(qualifier) if !@props || !@props[key]
        @props[key].to_s
      end

      def get_phoneinfo
        ADB.getphoneinfo(qualifier)
      end

      def install_apk(apk)
        ADB.install_apk(apk: apk, qualifier: qualifier)
      end

      def uninstall_apk(package_name)
        ADB.uninstall_apk(package_name: package_name, qualifier: qualifier)
      end

      def get_dpi
        ADB.get_device_dpi(qualifier)
      end
    end

    class DeviceDisconnectedWhenNotARemoteDevice < StandardError
      def initialize(msg)
        super(msg)
      end
    end
  end
end
