module PostHandlers

  class TestHandler_1

    def TestHandler_1.process_attribute values, context
      (values.kind_of? Array) ? values.map {|e| "p-" + e } : "p-#{values}"
    end

    def TestHandler_1.process_test entity
      entity.processed = true
      entity
    end
  end

end
