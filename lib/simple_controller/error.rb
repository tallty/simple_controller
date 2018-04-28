module SimpleController
  class Error < StandardError
    attr_reader :message, :code, :status
    def initialize(message, code, status)
      super(message)
      @message, @code, @status = message, code, status
    end
  end
end