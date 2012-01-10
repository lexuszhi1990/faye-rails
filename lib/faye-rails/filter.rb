module FayeRails
  class Filter

    attr_accessor :server
    attr_reader   :channel

    # Create a new FayeRails::Filter which can be passed to
    # Faye::RackAdapter#add_extension.
    #
    # @param channel
    #   Optional channel name to limit messages to.
    # @param direction
    #   :in, :out or :any.
    # @param block
    #   A proc object to be called when filtering messages.
    def initialize(channel=nil, direction=:any, block)
      @channel = channel
      raise ArgumentError, "Block cannot be nil" unless block
      if (direction == :in) || (direction == :any)
        @in_filter = DSL.new(block)
      end
      if (direction == :out) || (direction == :any)
        @out_filter = DSL.new(block)
      end
    end

    def respond_to?(method)
      if (method == :incoming) 
        !!@in_filter
      elsif (method == :outgoing)
        !!@out_filter
      else
        super
      end
    end

    def incoming(message, callback)
      @in_filter.evaluate(message, channel, callback) if @in_filter
    end

    def outgoing(message, callback)
      @out_filter.evaluate(message, channel, callback) if @out_filter
    end

    def destroy
      if server
        server.remove_extension(self)
      end
    end

    class DSL

      # A small wrapper class around filter blocks to
      # add some sugar to ease filter (Faye extension)
      # creation.

      attr_reader :channel, :message, :callback, :original_message

      # @param block
      #   The block you wish to execute whenever a matching
      #   message is recieved.
      def initialize(block)
        raise ArgumentError, "Block cannot be nil" unless block
        @block = block
      end

      # Called by FayeRails::Filter when Faye passes
      # messages in for evaluation.
      # @param channel
      #  optional: if present then the block will only be called for matching messages, otherwise all messages will be passed.
      def evaluate(message, channel=nil, callback)
        @channel = channel
        @original_message = @message = message
        @callback = callback
        if @channel
          if message['channel'] == @channel
            instance_eval(&@block)
          else
            pass
          end
        else
          instance_eval(&@block)
        end
      end
      
      # Syntactic sugar around callback.call which passes
      # back the original message unmodified.
      def pass
        return callback.call(original_message)
      end

      # Syntactic sugar around callback.call which passes
      # the passed argument back to Faye in place of the 
      # original message.
      # @param new_message
      #   Replacement message to send back to Faye.
      def modify(new_message)
        return callback.call(new_message)
      end

      # Syntactic sugar around callback.call which adds
      # an error message to the message and passes it back
      # to Faye, which will send back a rejection message to
      # the sending client.
      # @param reason
      #   The error message to be sent back to the client.
      def block(reason="Message blocked by filter")
        new_message = message
        new_message['error'] = reason
        return callback.call(new_message)
      end

      # Syntactic sugar around callback.call which returns
      # nil to Faye - effectively dropping the message.
      def drop
        return callback.call(nil)
      end

    end

  end
end