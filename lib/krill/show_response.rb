module Krill

  # @api krill
  # Not working, hash does not cleanly extend 
  # INSTEAD of extending hash, Try to make this a decorator class which includes enumerable and defines each
  # ALSO try extending hash as a delegate class
  require 'delegate'
  class ShowResponse < SimpleDelegator

    def helloworld
      "hello world"
    end
    
    # Return the response that was stored under `var`. When used with 
    # a key associated with a table response-set, returns a list of responses
    # in order of the rows of the table.
    #
    # @param var [Symbol/String]  The var used for storing data
    #               in the get or select call from the ShowBlock
    def get_response var
      responses[var.to_sym]
    end

    # Returns data recorded in a specified row of an input table
    # @param var [Symbol/String]  the table key specified to store data under
    #               in the get
    # @param opts [Hash]  additional options
    # @option op [Operation]  the Operation for which to retrieve the table data
    #               for, supposing the table was made on an OperationsList
    # @option row [Integer]  the row index of the table for which to retrieve table data
    def get_table_response var, opts = {}
      case opts
      when opts[op] && opts[row]
        raise "get_table_data called with Invalid parameters - specify op or row, not both"
      when opts[op]
        opid = Operation.find(op).id # return op.id if passed an operation or the id itself
        return self[:table_input].find { |resp| resp[:key] == var.to_sym && resp[:opid] == opid }[:value]
      when opts[row]
        return self[:table_input].find { |resp| resp[:key] == var.to_sym && resp[:row] == row }[:value]
      else # neither op nor row was specified. Return an array of data in the same order as input row
        return self[:table_input].sort { |resp| resp[:row] }.map { |resp| resp[:value] }
      end
    end

    # TODO merge normal responses with table response arrays, accessible by their key
    def responses
      self.select { |key, value| key != :table_input && key != :timestamp }
    end

    def timestamp
      self[:timestamp]
    end
  end
end