# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Krill::ExecutionSandbox do
  let!(:test_user) { create(:user) }

  # A protocol with a simple show
  let(:simple_protocol) do
    create(
      :operation_type,
      name: 'simple',
      category: 'testing',
      protocol: 'class Protocol; def main; show { title \'blah\' }; end end',
      user: test_user
    )
  end

  # A protocol with a show including a reference to operations.
  # Will cause an error if show_block.missing_method not setup correctly
  let(:op_show_protocol) do
    create(
      :operation_type,
      name: 'op_show',
      category: 'testing',
      protocol: 'class Protocol; def main; show { title \'blah\'; note operations.first.name } end end',
      user: test_user
    )
  end

  # A protocol that raises a StandardError
  let(:raise_protocol) do
    create(
      :operation_type,
      name: 'raise_exception',
      category: 'testing',
      protocol: 'class Protocol; def main; raise \'the_exception\' end end',
      user: test_user
    )
  end

  # A protocol that calls Kernel.exit
  let(:exit_protocol) do
    create(
      :operation_type,
      name: 'system_exit',
      category: 'testing',
      protocol: 'class Protocol; def main; exit; end; end',
      user: test_user
    )
  end

  # A protocol with some funky syntax
  let(:bad_syntax_protocol) do
    create(
      :operation_type,
      name: 'bad_syntax',
      category: 'testing',
      protocol: 'class Protocol; def main; 1=2; end; end',
      user: test_user
    )
  end

  # A protocol that calls a recursive method with a stack overflow
  let(:stack_protocol) do
    create(
      :operation_type,
      name: 'stack overflow',
      category: 'testing',
      protocol: 'class Protocol; def main; again; end; def again; again; end; end;',
      user: test_user
    )
  end

  # A protocol that will cause a NoMemoryError.
  # Intentionally not testing for NoMemoryError, b/c it is awfully slow.
  #
  # let(:no_memory_protocol) do
  #   create(
  #     :operation_type,
  #     name: 'no memory protocol',
  #     category: 'testing',
  #     protocol: 'class Protocol; def main; limit = 2**31 - 2; \'a\' * limit; end; end',
  #     user: test_user
  #   )
  # end

  it 'expect simple protocol to have attributes created with' do
    job = create_job(protocol: simple_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect(sandbox.protocol).to respond_to(:debug)
    expect(sandbox.protocol.debug).to eq(true)
    expect(sandbox.protocol).to respond_to(:input)
    expect(sandbox.protocol.input).not_to be_nil
    expect(sandbox.protocol).to respond_to(:jid)
    expect(sandbox.protocol.jid).to eq(job.id)
  end

  it 'expect simple protocol to run without error' do
    job = create_job(protocol: simple_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect { sandbox.execute }.not_to raise_error
    expect(job).not_to be_error
    job.operations.each { |operation| expect(operation.status).to eq('done') }
    expect(job).to be_done
    expect(job.backtrace[1][:content]).to eq([{ title: 'blah' }])
  end

  it 'expect protocol with reference to operations in show to run without error' do
    job = create_job(protocol: op_show_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect { sandbox.execute }.not_to raise_error
    expect(job).not_to be_error
    job.operations.each { |operation| expect(operation.status).to eq('done') }
    expect(job).to be_done
    expect(job.backtrace[1][:content]).to eq([{ title: 'blah' }, { note: op_show_protocol.name }])
  end

  it 'expect protocol that raises exceptions to have error' do
    job = create_job(protocol: raise_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect { sandbox.execute }.to raise_error(Krill::KrillError)
    expect(job).to be_error
    job.operations.each { |operation| expect(operation.status).to eq('error') }
  end

  it 'expect protocol that calls exit to have error' do
    job = create_job(protocol: exit_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect { sandbox.execute }.to raise_error(Krill::KrillError)
    expect(job).to be_error
    job.operations.each { |operation| expect(operation.status).to eq('error') }
  end

  it 'expect protocol with bad syntax to have error when sandbox is created' do
    job = create_job(protocol: bad_syntax_protocol, user: test_user)
    expect { Krill::ExecutionSandbox.new(job: job, debug: true) }.to raise_error(Krill::KrillSyntaxError)
  end

  it 'expect protocol with stack overflow to have error' do
    job = create_job(protocol: stack_protocol, user: test_user)
    sandbox = Krill::ExecutionSandbox.new(job: job, debug: true)
    expect { sandbox.execute }.to raise_error(Krill::KrillError)
    expect(job).to be_error
    job.operations.each { |operation| expect(operation.status).to eq('error') }
  end

  def create_job(protocol:, user:)
    operation = make_operation(
      operation_type: protocol,
      user_id: user.id
    )
    plan = build_plan(operation: operation, user_id: user.id)
    make_job(
      operation_type: protocol,
      operations: plan.operations,
      user: user
    )
  end

  def build_plan(operation:, user_id:)
    plan = Plan.new(user_id: user_id, budget_id: Budget.all.first.id)
    plan.save
    pa = PlanAssociation.new(operation_id: operation.id, plan_id: plan.id)
    pa.save

    plan
  end

  def make_operation(operation_type:, user_id:)
    operation = operation_type.operations.create(
      status: 'pending',
      user_id: user_id
    )

    operation
  end

  def make_job(operation_type:, operations:, user:)
    job, _newops = operation_type.schedule(
      operations,
      user,
      Group.find_by_name('technicians')
    )

    job
  end
end
