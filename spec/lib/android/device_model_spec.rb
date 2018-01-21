require 'device_api/android/device_model'

describe DeviceAPI::Android::DeviceModel do
  subject { described_class }
  describe '#deviceModel' do
    it 'loads the CSV only once ' do
      expect(CSV).to receive(:read).once.and_call_original
      subject.devices
    end
  end

  describe '#search' do
    context 'with marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.search('Samsung', 'SM-A7000')).to eq 'Galaxy A7'
      end
    end

    context 'with lower case marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.search('Samsung', 'sM-A7000')).to eq 'Galaxy A7'
      end
    end

    context 'with a whitespace marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.search(' Advan digital', '7008')).to eq 'X7 Pro'
      end
    end

    context 'without marketing name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.search('Acer', 'E330')).to eq 'E330'
      end
    end

    context 'without marketing name using lower case name' do
      it 'should return the display name ' do
        subject.devices
        expect(subject.search('acer', 'e330')).to eq 'E330'
      end
    end

    context 'unknown device' do
      it 'should return the passed model name display name ' do
        subject.devices
        expect(subject.search('Some', 'Model')).to eq 'Model'
      end
    end
  end
end
