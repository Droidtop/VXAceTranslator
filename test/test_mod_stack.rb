require 'minitest/autorun'
require 'tmpdir'
require_relative '../Modules/ModStack'

class ModStackTest < Minitest::Test
  def test_mods_overlay_in_order_and_report_conflicts
    Dir.mktmpdir do |root|
      base = File.join(root, 'base')
      first = File.join(root, 'first')
      second = File.join(root, 'second')
      output = File.join(root, 'output')
      [base, first, second].each { |path| FileUtils.mkdir_p(File.join(path, 'Scripts')) }
      File.write(File.join(base, 'Scripts', '10 - Feature.rb'), 'base')
      File.write(File.join(first, 'Scripts', '10 - Feature.rb'), 'first')
      File.write(File.join(second, 'Scripts', '10 - Feature.rb'), 'second')
      File.write(File.join(second, 'Scripts', '10+1 - Cheese.rb'), 'cheese')
      File.write(File.join(first, 'mod.json'), JSON.generate(name: 'First'))
      File.write(File.join(second, 'mod.json'), JSON.generate(name: 'Cheese'))

      stack = ModStack.new(base, [first, second])
      stack.build(output)

      assert_equal 'second', File.read(File.join(output, 'Scripts', '10 - Feature.rb'))
      assert_equal 'cheese', File.read(File.join(output, 'Scripts', '10+1 - Cheese.rb'))
      assert_equal ['First', 'Cheese'], stack.conflicts.map(&:replacement_source)
    end
  end

  def test_translated_files_is_the_default_manifest_root
    Dir.mktmpdir do |root|
      base = File.join(root, 'base')
      mod = File.join(root, 'mod')
      output = File.join(root, 'output')
      FileUtils.mkdir_p(base)
      FileUtils.mkdir_p(File.join(mod, 'Translated Files'))
      File.write(File.join(mod, 'Translated Files', 'Actors.txt'), 'actors')

      ModStack.new(base, [mod]).build(output)

      assert_equal 'actors', File.read(File.join(output, 'Actors.txt'))
    end
  end

  def test_manifest_cannot_escape_mod_directory
    Dir.mktmpdir do |root|
      base = File.join(root, 'base')
      mod = File.join(root, 'mod')
      FileUtils.mkdir_p(base)
      FileUtils.mkdir_p(mod)
      File.write(File.join(mod, 'mod.json'), JSON.generate(translation_root: '..'))

      assert_raises(ArgumentError) { ModStack.new(base, [mod]) }
    end
  end
end
