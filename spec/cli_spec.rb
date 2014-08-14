require 'spec_helper'

describe Thunder::Cli::App do

  context 'When I run `thunder`' do
    it 'shows help output' do
      run_simple 'thunder'
      assert_exit_status 0      
      expect(all_output).to match <<-HELP.gsub(/^ {8}/, '')
        app commands:
          thunder config .*
          thunder config_import .*
          thunder help .*
          thunder keypair .*
          thunder poll .*
          thunder stack .*
      HELP
    end
  end
  
end
