module Puppet::Coverage

  def begin_coverage
    evaluate_main2 = lambda do
      programs = fetch_programs known_resource_types
      total_nodes, hit_nodes = determine_percentage programs
      require 'debug';
      require 'pry'; binding.pry
      puts "#{hit_nodes}/#{total_nodes}"
      puts "#{hit_nodes.to_f/total_nodes*100.0}%"
      original_evaluate_main
    end
    fetch_programs = lambda do |known_resource_types|
      programs = Set.new
      extract_code = lambda do |enum, programs|
        enum.each_value do |hc|
          code = hc.code
          if code != nil
            # find the root node of the code.
            while code.parent != nil
              code = code.parent
            end
            programs << code
          end
        end
      end
      extract_code.call(known_resource_types.hostclasses, programs)
      extract_code.call(known_resource_types.definitions, programs)
      programs
    end

    iter_children = lambda do |models|
      total_models = 0
      evaluated_models = 0
      models.each do |model|
          #require 'pry'; binding.pry
        evaluated_models += 1 if get_counts(model)
        total_models += 1
        p_total, p_hit = iter_children model.eAllContents
        total_models += p_total
        evaluated_models += p_hit
      end
      [total_models, evaluated_models]
    end

    get_counts = lambda do |model|
      adapted = Puppet::Pops::Adapters::CoverageAdapter.adapt(model)
      adapted.count
    end

    determine_percentage = lambda do |programs|
      total_models = 0
      evaluated_models = 0
      programs.each do |p|
        model = p.program_model
        evaluated_models += 1 if (get_counts model)
        total_models += 1
        p_total, p_evaluated = iter_children model.eAllContents
        total_models += p_total
        evaluated_models += p_evaluated
      end
      [total_models, evaluated_models]
    end


    Puppet::Parser::Compiler.class_eval do
      alias_method :original_evaluate_main, :evaluate_main
      define_method :fetch_programs, fetch_programs
      define_method :determine_percentage, determine_percentage
      define_method :get_counts, get_counts
      define_method :iter_children, iter_children
      define_method :evaluate_main, evaluate_main2
    end
  end

  def end_coverage
    Puppet::Parser::Compiler.class_eval do
      alias_method :evaluate_main, :original_evaluate_main
    end
  end

  def clear_coverage catalog
    known_resource_types = catalog.known_resource_types
    sweep_up_coverage = lambda do |models|
      models.each do model
        Puppet::Pops::Adapters::CoverageAdapter.clear(model)
        sweep_up_coverage model.eAllContents
      end
    end
    clear_coverage = lambda do
      programs = fetch_programs known_resource_types
      programs.each do |p|
        sweep_up_coverage.call(p)
      end
    end
    Puppet::Parser::Compiler.class_eval do

      define_method :sweep_up_coverage, sweep_up_coverage
      define_singleton_method :clear_coverage, clear_coverage
    end
    Puppet::Parser::Compiler.clear_coverage
  end
end
