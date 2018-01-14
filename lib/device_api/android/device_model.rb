require 'csv'

module Android
  module DeviceModel
    @csv_file = File.expand_path('device/devices.csv', File.dirname(__FILE__))

    def self.devices
      return @devices unless @devices.nil?

      rows = CSV.read(@csv_file)

      @devices = rows.each_with_object({}) do |(manufacturer, marketing_name, _device, model), devices|
        key = device_model_key(manufacturer, model)
        devices[key] = (marketing_name || model) if model && manufacturer
      end
    end

    def self.marketing_name(manufacturer, model)
      key = device_model_key(manufacturer, model)
      model && manufacturer ? @devices[key] || model : model
    end

    private

    def self.device_model_key(manufacturer, model)
      [manufacturer, model].map do |item|
        item.to_s.strip.tr(' ', '_').downcase
      end.join('')
    end
  end
end
