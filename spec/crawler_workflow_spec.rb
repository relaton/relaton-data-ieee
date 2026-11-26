# frozen_string_literal: true

require "yaml"

RSpec.describe ".github/workflows/crawler.yml" do
  file = File.expand_path("../.github/workflows/crawler.yml", __dir__)
  let(:text) { File.read(file) }
  # Psych reads the bare `on:` key as `true`.
  let(:yaml) { YAML.safe_load(text) }
  let(:triggers) { yaml[true] }
  let(:job) { yaml.dig("jobs", "crawl") }

  it "is the repo's own file, not a Cimas copy" do
    expect(text).not_to include("Cimas")
  end

  it "keeps the name that deploy.yml's workflow_run matches" do
    expect(yaml["name"]).to eq("Crawler")
  end

  it "runs daily and on workflow_dispatch with args" do
    expect(triggers["schedule"]).to eq([{ "cron" => "37 14 * * *" }])
    expect(triggers.dig("workflow_dispatch", "inputs", "args", "default")).to eq("")
    expect(triggers.keys).to contain_exactly("schedule", "workflow_dispatch")
  end

  it "calls the shared crawler with write access" do
    expect(job["uses"]).to eq("relaton/support/.github/workflows/crawler.yml@main")
    expect(job["permissions"]).to eq("contents" => "write")
    expect(job.dig("with", "args")).to eq("${{ github.event.inputs.args }}")
  end

  it "passes the ieee-rawbib PAT as the secret args" do
    expect(job.dig("secrets", "args")).to eq("${{ secrets.IEEE_RAWBIB_TOKEN }}")
  end
end
