require 'csv'

module DeviceAPI
  module Android
    module DeviceModel
      def self.search(manufacturer, device_model, type = nil)
        key_type = type || :name
        key = device_model_key(manufacturer, device_model)

        if models.key?(key)
          models[key][key_type]
        elsif key_type == :name
          device_model
        end
      end

      def self.devices
        return @devices unless @device_list.nil?

        @csv_file = File.join(File.dirname(File.expand_path(__FILE__)), '/devices/devices.csv')
        @devices  = CSV.read(@csv_file)
      end

      def self.models
        return @models unless @models.nil?
        @models = {}
        devices.shift
        devices.each do |(manufacturer, marketing_name, device, model)|
          device_type = device_model_key(manufacturer, model)

          @models[device_type] = { manufacturer: manufacturer,
                                   name: marketing_name || model,
                                   device: device,
                                   model: model }
        end
        @models
      end

      private

      def self.device_model_key(manufacturer, model)
        [manufacturer, model].map { |item| item.to_s.strip.tr(' ', '_').downcase }.join('')
      end
    end
  end
end
