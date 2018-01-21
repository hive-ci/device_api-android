require 'csv'
require 'open-uri'

task :update do
  puts 'Fetching Data'
  csv_url = 'http://storage.googleapis.com/play_public/supported_devices.csv'
  devices = CSV.parse(open(csv_url).read)

  File.open('lib/device_api/android/devices/devices.csv', 'w') do |file|
    puts 'Writing to File'
    file.write(devices.inject([]) { |csv, row| csv << CSV.generate_line(row) }
    .join('').encode('UTF-8'))
  end
end
