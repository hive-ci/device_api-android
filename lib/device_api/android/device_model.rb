require 'csv'

module DeviceAPI
  module Android
    class DeviceModel < Device
      @csv_file = File.expand_path('device/devices.csv', File.dirname(__FILE__))

      def self.marketing_name(manufacturer, model)
        key = device_model_key(manufacturer, model)
        device_list.key?(key) ? device_list[key] : model
      end

      private

      def self.device_list
        return @devices unless @devices.nil?
        device_list = {}
        rows = CSV.read(@csv_file)

        rows.each_with_object({}) do |(manufacturer, marketing_name, _device, model), _devices|
          key = device_model_key(manufacturer, model)
          device_list[key] = (marketing_name || model) if model && manufacturer
        end
        device_list
      end

      def self.device_model_key(manufacturer, model)
        [manufacturer, model].map do |item|
          item.to_s.strip.tr(' ', '_').downcase
        end.join('')
      end
    end
  end
end
