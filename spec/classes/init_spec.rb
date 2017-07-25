require 'spec_helper'
describe 'voip-servidor' do

  context 'with defaults for all parameters' do
    it { should contain_class('voip-servidor') }
  end
end
