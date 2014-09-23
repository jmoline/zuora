require 'scanf'

module Zuora
  class Version
    MAJOR = 1
    MINOR = 0
    PATCH = 1

    def self.to_s
      "#{MAJOR}.#{MINOR}.#{PATCH}"
    end
  end
end
