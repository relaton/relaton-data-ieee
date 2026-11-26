# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "crawler.rb" do
  root = File.expand_path("..", __dir__)
  crawler = File.join(root, "crawler.rb")
  stub_lib = File.join(__dir__, "support", "lib")
  fake_bin = File.join(__dir__, "support", "bin")
  token = "ghp_spec_secret_0123456789"

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      FileUtils.mkdir_p(File.join(dir, "data"))
      File.write(File.join(dir, "data", "old.yaml"), "old")
      File.write(File.join(dir, "index-v1.yaml"), "v1")
      File.write(File.join(dir, "index-v1.zip"), "v1")
      example.run
    end
  end

  def path(*parts) = File.join(@dir, *parts)

  def git_log = File.exist?(path("git.log")) ? File.read(path("git.log")) : ""

  define_method(:run_crawler) do |*args, fail_clone: false, empty_clone: false|
    env = {
      "PATH" => "#{fake_bin}:#{ENV.fetch('PATH')}",
      "FAKE_GIT_LOG" => path("git.log"),
      "FAKE_GIT_FAIL" => fail_clone ? "1" : "0",
      "FAKE_GIT_EMPTY" => empty_clone ? "1" : "0",
    }
    Bundler.with_unbundled_env do
      Open3.capture3(env, "ruby", "-I", stub_lib, crawler, *args, chdir: @dir)
    end
  end

  it "aborts and keeps data/ without a token and without a local source" do
    _out, err, status = run_crawler
    expect(status).not_to be_success
    expect(err).to include("IEEE_RAWBIB_TOKEN")
    expect(File.exist?(path("data", "old.yaml"))).to be true
    expect(git_log).to be_empty
  end

  it "aborts, keeps data/ and masks the token when the clone fails" do
    out, err, status = run_crawler(token, fail_clone: true)
    expect(status).not_to be_success
    expect(err).to include("cannot clone")
    expect(err).to include("fatal: repository 'https://oauth2:***@github.com/")
    expect(out + err).not_to include(token)
    expect(File.exist?(path("data", "old.yaml"))).to be true
    expect(File.exist?(path("index-v1.yaml"))).to be true
  end

  it "takes the token as the last argument" do
    run_crawler("--extra", token)
    expect(git_log).to include("oauth2:#{token}@")
  end

  it "does not take an ordinary last argument as the token" do
    _out, err, status = run_crawler("--extra")
    expect(status).not_to be_success
    expect(err).to include("IEEE_RAWBIB_TOKEN")
    expect(git_log).to be_empty
  end

  it "fails and builds no index when the clone gives no documents" do
    _out, err, status = run_crawler(token, empty_clone: true)
    expect(status).not_to be_success
    expect(err).to include("gave no documents")
    expect(File.exist?(path("index-v2.yaml"))).to be false
    expect(File.exist?(path("ieee-rawbib"))).to be false
  end

  context "when the clone succeeds" do
    before { @result = run_crawler(token) }

    it "clones ietf-tools/ieee-rawbib with depth 1" do
      expect(@result[2]).to be_success, @result[1]
      expect(git_log).to include(
        "clone --depth 1 --quiet https://oauth2:#{token}@github.com/ietf-tools/ieee-rawbib.git ieee-rawbib",
      )
    end

    it "replaces data/ from the clone" do
      expect(File.exist?(path("data", "old.yaml"))).to be false
      expect(File.read(path("data", "new.yaml"))).to eq("ieee-rawbib/cloned.xml")
    end

    it "deletes index-v1 and builds index-v2" do
      expect(Dir.glob(path("index-v1*"))).to be_empty
      expect(File.read(path("index-v2.yaml"))).to eq("data/new.yaml")
    end

    it "removes the clone" do
      expect(File.exist?(path("ieee-rawbib"))).to be false
    end

    it "does not print the token" do
      expect(@result[0] + @result[1]).not_to include(token)
    end
  end

  context "with a local ieee-rawbib" do
    before do
      FileUtils.mkdir_p(path("ieee-rawbib"))
      File.write(path("ieee-rawbib", "local.xml"), "<doc/>")
      @result = run_crawler
    end

    it "reads it without a clone and keeps it" do
      expect(@result[2]).to be_success, @result[1]
      expect(git_log).to be_empty
      expect(File.read(path("data", "new.yaml"))).to eq("ieee-rawbib/local.xml")
      expect(File.exist?(path("ieee-rawbib", "local.xml"))).to be true
    end
  end

  context "with a dangling ieee-rawbib symlink" do
    before do
      File.symlink(path("missing"), path("ieee-rawbib"))
      @result = run_crawler(token)
    end

    it "neither clones nor deletes it" do
      expect(@result[2]).not_to be_success
      expect(git_log).to be_empty
      expect(File.symlink?(path("ieee-rawbib"))).to be true
    end
  end
end
