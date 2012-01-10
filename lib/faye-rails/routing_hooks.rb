if defined? ActionDispatch::Routing

  module ActionDispatch::Routing
    class Mapper

      def faye_server(mount_path, options={}, &block)

        defaults = {
          :enable_websockets => false,
          :mount => mount_path||'/faye',
          :timeout => 25,
          :engine => nil
        }

        unknown_options = options.keys - defaults.keys
        if unknown_options.one?
          raise ArgumentError, "Unknown option: #{unknown_options.first}."
        elsif unknown_options.any?
          raise ArgumentError, "Unknown options: #{unknown_options * ", "}."
        end

        options = defaults.merge(options)

        adapter = FayeRails::RackAdapter.new(options)
        adapter.instance_eval(&block) if block.respond_to? :call

        match options[:mount] => adapter

        ::Faye.ensure_reactor_running!

      end

    end
  end

end

if defined? Rails::Application::RoutesReloader

  class Rails::Application::RoutesReloader

    def clear_with_faye_servers!
      FayeRails.servers.clear!
      clear_without_faye_servers!
    end

    alias clear_without_faye_servers! clear!
    alias clear! clear_with_faye_servers!

  end

end