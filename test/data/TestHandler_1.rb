module PostHandlers

  class TestHandler_1
    def TestHandler_1.process_test entity
      entity.processed = true
      entity
    end
  end

end
