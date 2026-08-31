require 'fileutils'
require 'find'
require 'json'
require 'tmpdir'

class ModStack
  Mod = Struct.new(:path, :name, :version, :description, :translation_root, keyword_init: true)
  Conflict = Struct.new(:relative_path, :previous_source, :replacement_source, keyword_init: true)

  attr_reader :base_path, :mods, :conflicts

  def initialize(base_path, mod_paths = [])
    @base_path = File.expand_path(base_path)
    @mods = mod_paths.map { |path| load_mod(path) }
    @conflicts = []
  end

  def entries
    [{ name: 'Base translation', path: @base_path, version: nil }] + @mods.map do |mod|
      { name: mod.name, path: mod.path, version: mod.version, description: mod.description }
    end
  end

  def build(destination)
    raise ArgumentError, "Translation directory does not exist: #{@base_path}" unless Dir.exist?(@base_path)

    @conflicts.clear
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    owners = {}
    overlay(@base_path, destination, 'Base translation', owners)
    @mods.each { |mod| overlay(mod.translation_root, destination, mod.name, owners) }
    destination
  end

  def with_staging_directory
    Dir.mktmpdir('vxace-translator-') do |directory|
      build(directory)
      yield directory
    end
  end

  private

  def load_mod(path)
    expanded = File.expand_path(path)
    raise ArgumentError, "Mod directory does not exist: #{expanded}" unless Dir.exist?(expanded)

    manifest_path = File.join(expanded, 'mod.json')
    manifest = File.exist?(manifest_path) ? JSON.parse(File.read(manifest_path, encoding: 'UTF-8')) : {}
    relative_root = manifest.fetch('translation_root', Dir.exist?(File.join(expanded, 'Translated Files')) ? 'Translated Files' : '.')
    translation_root = File.expand_path(relative_root, expanded)
    unless translation_root == expanded || translation_root.start_with?(expanded + File::SEPARATOR)
      raise ArgumentError, "Mod translation_root escapes its directory: #{expanded}"
    end
    raise ArgumentError, "Mod translation directory does not exist: #{translation_root}" unless Dir.exist?(translation_root)

    Mod.new(
      path: expanded,
      name: manifest.fetch('name', File.basename(expanded)),
      version: manifest['version'],
      description: manifest['description'],
      translation_root: translation_root
    )
  end

  def overlay(source, destination, source_name, owners)
    Find.find(source).sort.each do |path|
      next if path == source || File.basename(path) == 'mod.json'

      relative = path.delete_prefix(source).sub(%r{\A[\\/]}, '')
      target = File.join(destination, relative)
      if File.directory?(path)
        FileUtils.mkdir_p(target)
        next
      end

      previous = owners[relative]
      @conflicts << Conflict.new(relative_path: relative, previous_source: previous, replacement_source: source_name) if previous
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.copy_file(path, target)
      owners[relative] = source_name
    end
  end
end
