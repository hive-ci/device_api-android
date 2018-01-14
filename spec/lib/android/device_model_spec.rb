require 'time'
require 'device_api/android/device_model'

describe Android::DeviceModel do
  subject { described_class }
  describe '#deviceModel' do
    it 'loads the CSV only once ' do
      expect(CSV).to receive(:read).once.and_call_original
      subject.devices
      subject.devices
    end
  end

  describe '#marketing_name' do
    context 'with marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.marketing_name('Samsung', 'SM-A7000')).to eq 'Galaxy A7'
      end
    end

    context 'with lower case marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.marketing_name('Samsung', 'sM-A7000')).to eq 'Galaxy A7'
      end
    end

    context 'with a whitespace marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.marketing_name(' Advan digital', '7008')).to eq 'X7 Pro'
      end
    end

    context 'without marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.marketing_name('Acer', 'E330')).to eq 'E330'
      end
    end

    context 'without marketing name using lower case name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.marketing_name('acer', 'e330')).to eq 'E330'
      end
    end

    context 'unknown device' do
      it 'should return the passed model name display name ' do
        subject.devices
        expect(subject.marketing_name('Some', 'Model')).to eq 'Model'
      end
    end
  end
end
