# frozen_string_literal: true

module SendKit
  class Error < StandardError
    attr_reader :name, :status_code

    def initialize(message, name: "application_error", status_code: nil)
      super(message)
      @name = name
      @status_code = status_code
    end
  end
end
