module OperationPlanner

  def associate_plan plan
    pa = plan_associations.create plan_id: plan.id
    pa.save
    if !plan.user_id
      plan.user_id = user_id
      plan.save
    end
  end

  def ready?

    operation_type.inputs.each do |i|

      input_list = inputs.select { |j| j.name == i.name }

      if input_list.empty? # && !i.array # arrays need to have at least one element (for now)
        return false
      else
        input_list.each do |j|
          if ! j.satisfied_by_environment
            return false
          end
        end
      end

    end

    return true

  end

  def leaf?
    inputs.each do |i|
      if i.predecessors.count > 0
        return false
      end
    end
    return true
  end

  def undetermined_inputs?

    operation_type.inputs.each do |i|
      input_list = inputs.select { |j| j.name == i.name }
      if input_list.empty? # && ! i.array # arrays need to have at least one element (for now)
        return true
      end
    end

    return false

  end

  def has_no_stock_or_method
    inputs.each do |i|
      if !i.satisfied_by_environment && i.predecessors.length == 0
        return true
      end
    end
    return false
  end

  def issues

    issues = []

    recurse do |op|
      if op.status == "planning" && op.leaf? && !op.ready?
        issues << { id: op.id, leaf: true, msg: "not ready" }
      elsif op.status == "planning" && op.undetermined_inputs?
        issues << { id: op.id, leaf: op.ready?, msg: "unspecified inputs" }
      elsif op.has_no_stock_or_method
        issues << { id: op.id, leaf: op.ready?, msg: "no way to make at least one input"}
      end
    end

    return issues

  end

  def show_plan space=""

    op = self

    if op.status == "planning"
      print "#{space}\e[95m#{op.operation_type.name} #{op.id}, status: #{op.status}\e[39m"
    else
      print "#{space}\e[90m#{op.operation_type.name} #{op.id}, status: #{op.status}\e[39m"      
    end

    if op.ready?
      puts ", ready"
    else
      puts ", not ready"
    end

    op.operation_type.inputs.each do |j|

      input_list = op.inputs.each.select { |i| i.name == j.name }

      input_list.each do |i| # note: array inputs may have multiple fvs with the same name

        print "  #{space}+ #{i.sample_type.name}"
        print " #{i.child_sample.name}"
        print " (#{i.object_type ? i.object_type.name : 'NO OBJECT TYPE'})"

        if i.predecessors.length > 0
          puts " ... #{i.predecessors.length} option(s)"
        elsif i.satisfied_by_environment
          puts " ... available"
        else
          puts " ... no inventory and no way to make this sample"
        end

        i.predecessors.each do |p|
          p.operation.show_plan space+"    "
        end

      end

      if input_list.empty?
        afts = j.allowable_field_types.collect { |aft| aft.sample_type.name }.join(',')
        puts "  #{space}+ #{j.name} (#{afts}): NOT DETERMINED (by Operation.instantiate)"
      end

    end

  end  

  def serialize override_status=nil

    problem = false

    {

      id: id,
      operation_type_id: operation_type_id,
      status: override_status ? override_status : status,
      ready: ready?,

      inputs: inputs.collect { |i| 

        sat = i.satisfied_by_environment
        preds = i.predecessors
        os = override_status if (override_status)
        os = status if (!override_status && status == "unplanned")
        problem = !sat && preds.length == 0

        {
          name: i.name,
          satisfied: sat,
          issue: !sat && preds.length == 0,
          predecessors: preds.collect { |p|
            {
              id: p.id,
              name: p.name,
              operation: p.operation.serialize(os)
            }
          }
        }

      },

      problem: problem

    }

  end

end






















