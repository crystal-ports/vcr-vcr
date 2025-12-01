vcr.cr
======

Record your test suite's HTTP interactions and replay them during future test runs for fast, deterministic, accurate tests.

This is a **Crystal** port of the popular Ruby [VCR](https://github.com/vcr/vcr) gem.

**Help Wanted**

We're looking for more maintainers. If you'd like to help maintain a well-used shard please spend some time reviewing pull requests, issues, or participating in discussions.

Installation
============

Add this to your `shard.yml`:

```yaml
dependencies:
  vcr:
    github: crystal-ports/vcr-vcr
```

Then run:

```console
shards install
```

Usage
=====

```crystal
require "spec"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :http_client
end

describe "VCR Example" do
  it "records and replays HTTP interactions" do
    VCR.use_cassette("synopsis") do
      response = HTTP::Client.get("http://www.iana.org/domains/reserved")
      response.body.should contain("Example domains")
    end
  end
end
```

Run this test once, and VCR will record the HTTP request to `fixtures/vcr_cassettes/synopsis.yml`. Run it again, and VCR will replay the response from iana.org when the HTTP request is made. This test is now fast (no real HTTP requests are made anymore), deterministic (the test will continue to pass, even if you are offline, or iana.org goes down for maintenance) and accurate (the response will contain the same headers and body you get from a real request). You can use a different cassette library directory (e.g., "spec/vcr_cassettes").

NOTE: To avoid storing any sensitive information in cassettes, check out [Filter Sensitive Data](https://benoittgt.github.io/vcr/#/configuration/filter_sensitive_data) in the documentation.

**Features**

  * Automatically records and replays your HTTP interactions with minimal setup/configuration code.
  * Hooks into Crystal's standard `HTTP::Client` library.
  * Request matching is configurable based on HTTP method, URI, host, path, body and headers, or you can easily implement a custom request matcher to handle any need.
  * The same request can receive different responses in different tests--just use different cassettes.
  * The recorded requests and responses are stored on disk in a serialization format of your choice (currently YAML and JSON are built in, and you can easily implement your own custom serializer) and can easily be inspected and edited.
  * Dynamic responses are supported using ECR (Embedded Crystal).
  * Optionally re-records cassettes on a configurable regular interval to keep them fresh and current.
  * Disables all HTTP requests that you don't explicitly allow.
  * Includes convenient [Spectator](https://gitlab.com/arctic-fox/spectator) integration with metadata support.
  * Known to work well with Crystal's testing frameworks including Spectator and minitest.cr.
  * Supports filtering sensitive data from the response body

The docs come in two flavors:

  * The [usage docs](https://benoittgt.github.io/vcr) contain example-based documentation. It's a good place to look when you are first getting started with VCR, or if you want to see an example of how to use a feature.
  * See the [CHANGELOG](https://github.com/crystal-ports/vcr-vcr/blob/master/CHANGELOG.md) doc for info about what's new and changed.

This is a Crystal port of the original Ruby VCR library. While the API is largely similar, there are some Crystal-specific differences.

**Release Policy**

VCR follows the principles of [semantic versioning](https://semver.org/). Patch level releases contain only bug fixes. Minor releases contain backward-compatible new features. Major new releases contain backwards-incompatible changes to the public API.

**Crystal Version Compatibility**

VCR.cr is tested on:

  * Crystal 1.16.3+

See the `shard.yml` for the minimum required Crystal version.

**Development**

  * Source hosted on [GitHub](https://github.com/crystal-ports/vcr-vcr).
  * Direct questions and discussions on [GitHub Issues](https://github.com/crystal-ports/vcr-vcr/issues).
  * Report bugs/issues on [GitHub Issues](https://github.com/crystal-ports/vcr-vcr/issues).
  * Pull requests are very welcome! Please include spec coverage for every patch,
    and create a topic branch for every separate change you make.
  * See the [Contributing](https://github.com/crystal-ports/vcr-vcr/blob/master/CONTRIBUTING.md)
    guide for instructions on running the specs.
  * Code quality is checked with [Ameba](https://github.com/crystal-ameba/ameba).

To run specs:

```
crystal spec
```

To run the linter:

```
./bin/ameba
```

**Ports in Other Languages**

  * [VCR](https://github.com/vcr/vcr) (Ruby - original implementation)
  * [Betamax](https://github.com/sigmavirus24/betamax) (Python)
  * [VCR.py](https://github.com/kevin1024/vcrpy) (Python)
  * [Betamax](https://github.com/thegreatape/betamax) (Go)
  * [DVR](https://github.com/orchestrate-io/dvr) (Go)
  * [Go VCR](https://github.com/dnaeon/go-vcr) (Go)
  * [vcr-clj](https://github.com/gfredericks/vcr-clj) (Clojure)
  * [scotch](https://github.com/mleech/scotch) (C#/.NET)
  * [Betamax.NET](https://github.com/mfloryan/Betamax.Net) (C#/.NET)
  * [Vcr.HttpRecorder](https://github.com/GeorgopoulosGiannis/Vcr.HttpRecorder) (C#/.NET)
  * [ExVCR](https://github.com/parroty/exvcr) (Elixir)
  * [VCR](https://github.com/assertible/vcr) (Haskell)
  * [Mimic](https://github.com/acoulton/mimic) (PHP/Kohana)
  * [PHP-VCR](https://github.com/php-vcr/php-vcr) (PHP)
  * [Talkback](https://github.com/ijpiantanida/talkback) (JavaScript/Node)
  * [NSURLConnectionVCR](https://bitbucket.org/martijnthe/nsurlconnectionvcr) (Objective-C)
  * [VCRURLConnection](https://github.com/dstnbrkr/VCRURLConnection) (Objective-C)
  * [DVR](https://github.com/venmo/DVR) (Swift)
  * [VHS](https://github.com/diegoeche/vhs) (Erlang)
  * [Betamax](https://github.com/betamaxteam/betamax) (Java)
  * [http_replayer](https://github.com/ucarion/http_replayer) (Rust)
  * [OkReplay](https://github.com/airbnb/okreplay) (Java/Android)
  * [vcr](https://github.com/ropensci/vcr) (R)

**Other Libraries in Crystal**

  * [eighttrack](https://github.com/russ/eighttrack)
  * [hi8.cr](https://github.com/vonKingsley/hi8.cr)
  * [webmock.cr](https://github.com/manastech/webmock.cr)


Credits
=======

  * [Aslak Hellesøy](https://github.com/aslakhellesoy) for [Cucumber](https://github.com/aslakhellesoy/cucumber).
  * [Bartosz Blimke](https://github.com/bblimke) for [WebMock](https://github.com/bblimke/webmock).
  * [Chris Kampmeier](https://github.com/chrisk) for [FakeWeb](https://github.com/chrisk/fakeweb).
  * [Chris Young](https://github.com/chrisyoung) for [NetRecorder](https://github.com/chrisyoung/netrecorder),
    the inspiration for VCR.
  * [David Balatero](https://github.com/dbalatero) and [Hans Hasselberg](https://github.com/i0rek)
    for help with [Typhoeus](https://github.com/typhoeus/typhoeus) support.
  * [Wesley Beary](https://github.com/geemus) for help with [Excon](https://github.com/geemus/excon)
    support.
  * [Jacob Green](https://github.com/Jacobkg) for help with ongoing VCR
    maintenance.
  * [Jan Berdajs](https://github.com/mrbrdo) and [Daniel Berger](https://github.com/djberg96)
    for improvements to thread-safety.


Thanks also to the following people who have contributed patches or helpful suggestions:

  * [Aaron Brethorst](https://github.com/aaronbrethorst)
  * [Alexander Wenzowski](https://github.com/wenzowski)
  * [Austen Ito](https://github.com/austenito)
  * [Avdi Grimm](https://github.com/avdi)
  * [Bartosz Blimke](http://github.com/bblimke)
  * [Benjamin Oakes](https://github.com/benjaminoakes)
  * [Ben Hutton](https://github.com/benhutton)
  * [Bradley Isotope](https://github.com/bradleyisotope)
  * [Carlos Kirkconnell](https://github.com/kirkconnell)
  * [Chad Jolly](https://github.com/cjolly)
  * [Chris Le](https://github.com/chrisle)
  * [Chris Gunther](https://github.com/cgunther)
  * [Eduardo Maia](https://github.com/emaiax)
  * [Eric Allam](https://github.com/rubymaverick)
  * [Ezekiel Templin](https://github.com/ezkl)
  * [Flaviu Simihaian](https://github.com/closedbracket)
  * [Gordon Wilson](https://github.com/gordoncww)
  * [Hans Hasselberg](https://github.com/i0rek)
  * [Herman Verschooten](https://github.com/Hermanverschooten)
  * [Ian Cordasco](https://github.com/sigmavirus24)
  * [Ingemar](https://github.com/ingemar)
  * [Ilya Scharrenbroich](https://github.com/quidproquo)
  * [Jacob Green](https://github.com/Jacobkg)
  * [James Bence](https://github.com/jbence)
  * [Jay Shepherd](https://github.com/jayshepherd)
  * [Jeff Pollard](https://github.com/Fluxx)
  * [Joe Nelson](https://github.com/begriffs)
  * [Jonathan Tron](https://github.com/JonathanTron)
  * [Justin Smestad](https://github.com/jsmestad)
  * [Karl Baum](https://github.com/kbaum)
  * [Kris Luminar](https://github.com/kris-luminar)
  * [Kurt Funai](https://github.com/kurtfunai)
  * [Luke van der Hoeven](https://github.com/plukevdh)
  * [Mark Burns](https://github.com/markburns)
  * [Max Riveiro](https://github.com/kavu)
  * [Michael Lavrisha](https://github.com/vrish88)
  * [Michiel de Mare](https://github.com/mdemare)
  * [Mike Dalton](https://github.com/kcdragon)
  * [Mislav Marohnić](https://github.com/mislav)
  * [Nathaniel Bibler](https://github.com/nbibler)
  * [Noah Davis](https://github.com/noahd1)
  * [Oliver Searle-Barnes](https://github.com/opsb)
  * [Omer Rauchwerger](https://github.com/rauchy)
  * [Paco Guzmán](https://github.com/pacoguzman)
  * [Paul Morgan](https://github.com/jumanjiman)
  * [playupchris](https://github.com/playupchris)
  * [Ron Smith](https://github.com/ronwsmith)
  * [Ryan Bates](https://github.com/ryanb)
  * [Ryan Burrows](https://github.com/rhburrows)
  * [Ryan Castillo](https://github.com/rmcastil)
  * [Sathya Sekaran](https://github.com/sfsekaran)
  * [Scott Carleton](https://github.com/ScotterC)
  * [Shay Frendt](https://github.com/shayfrendt)
  * [Steve Faulkner](https://github.com/southpolesteve)
  * [Stephen Anderson](https://github.com/bendycode)
  * [Todd Lunter](https://github.com/tlunter)
  * [Tyler Hunt](https://github.com/tylerhunt)
  * [Uģis Ozols](https://github.com/ugisozols)
  * [vzvu3k6k](https://github.com/vzvu3k6k)
  * [Wesley Beary](https://github.com/geemus)


# Backers

Support us with a monthly donation and help us continue our activities. [[Become a backer](https://opencollective.com/vcr#backer)]

<a href="https://opencollective.com/vcr/backer/0/website" target="_blank"><img src="https://opencollective.com/vcr/backer/0/avatar"></a>
<a href="https://opencollective.com/vcr/backer/1/website" target="_blank"><img src="https://opencollective.com/vcr/backer/1/avatar"></a>
<a href="https://opencollective.com/vcr/backer/2/website" target="_blank"><img src="https://opencollective.com/vcr/backer/2/avatar"></a>
<a href="https://opencollective.com/vcr/backer/3/website" target="_blank"><img src="https://opencollective.com/vcr/backer/3/avatar"></a>
<a href="https://opencollective.com/vcr/backer/4/website" target="_blank"><img src="https://opencollective.com/vcr/backer/4/avatar"></a>
<a href="https://opencollective.com/vcr/backer/5/website" target="_blank"><img src="https://opencollective.com/vcr/backer/5/avatar"></a>
<a href="https://opencollective.com/vcr/backer/6/website" target="_blank"><img src="https://opencollective.com/vcr/backer/6/avatar"></a>
<a href="https://opencollective.com/vcr/backer/7/website" target="_blank"><img src="https://opencollective.com/vcr/backer/7/avatar"></a>
<a href="https://opencollective.com/vcr/backer/8/website" target="_blank"><img src="https://opencollective.com/vcr/backer/8/avatar"></a>
<a href="https://opencollective.com/vcr/backer/9/website" target="_blank"><img src="https://opencollective.com/vcr/backer/9/avatar"></a>
<a href="https://opencollective.com/vcr/backer/10/website" target="_blank"><img src="https://opencollective.com/vcr/backer/10/avatar"></a>
<a href="https://opencollective.com/vcr/backer/11/website" target="_blank"><img src="https://opencollective.com/vcr/backer/11/avatar"></a>
<a href="https://opencollective.com/vcr/backer/12/website" target="_blank"><img src="https://opencollective.com/vcr/backer/12/avatar"></a>
<a href="https://opencollective.com/vcr/backer/13/website" target="_blank"><img src="https://opencollective.com/vcr/backer/13/avatar"></a>
<a href="https://opencollective.com/vcr/backer/14/website" target="_blank"><img src="https://opencollective.com/vcr/backer/14/avatar"></a>
<a href="https://opencollective.com/vcr/backer/15/website" target="_blank"><img src="https://opencollective.com/vcr/backer/15/avatar"></a>
<a href="https://opencollective.com/vcr/backer/16/website" target="_blank"><img src="https://opencollective.com/vcr/backer/16/avatar"></a>
<a href="https://opencollective.com/vcr/backer/17/website" target="_blank"><img src="https://opencollective.com/vcr/backer/17/avatar"></a>
<a href="https://opencollective.com/vcr/backer/18/website" target="_blank"><img src="https://opencollective.com/vcr/backer/18/avatar"></a>
<a href="https://opencollective.com/vcr/backer/19/website" target="_blank"><img src="https://opencollective.com/vcr/backer/19/avatar"></a>
<a href="https://opencollective.com/vcr/backer/20/website" target="_blank"><img src="https://opencollective.com/vcr/backer/20/avatar"></a>
<a href="https://opencollective.com/vcr/backer/21/website" target="_blank"><img src="https://opencollective.com/vcr/backer/21/avatar"></a>
<a href="https://opencollective.com/vcr/backer/22/website" target="_blank"><img src="https://opencollective.com/vcr/backer/22/avatar"></a>
<a href="https://opencollective.com/vcr/backer/23/website" target="_blank"><img src="https://opencollective.com/vcr/backer/23/avatar"></a>
<a href="https://opencollective.com/vcr/backer/24/website" target="_blank"><img src="https://opencollective.com/vcr/backer/24/avatar"></a>
<a href="https://opencollective.com/vcr/backer/25/website" target="_blank"><img src="https://opencollective.com/vcr/backer/25/avatar"></a>
<a href="https://opencollective.com/vcr/backer/26/website" target="_blank"><img src="https://opencollective.com/vcr/backer/26/avatar"></a>
<a href="https://opencollective.com/vcr/backer/27/website" target="_blank"><img src="https://opencollective.com/vcr/backer/27/avatar"></a>
<a href="https://opencollective.com/vcr/backer/28/website" target="_blank"><img src="https://opencollective.com/vcr/backer/28/avatar"></a>
<a href="https://opencollective.com/vcr/backer/29/website" target="_blank"><img src="https://opencollective.com/vcr/backer/29/avatar"></a>


# Sponsors

Become a sponsor and get your logo on our README on Github with a link to your site. [[Become a sponsor](https://opencollective.com/vcr#sponsor)]

<a href="https://opencollective.com/vcr/sponsor/0/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/0/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/1/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/1/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/2/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/2/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/3/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/3/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/4/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/4/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/5/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/5/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/6/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/6/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/7/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/7/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/8/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/8/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/9/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/9/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/10/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/10/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/11/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/11/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/12/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/12/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/13/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/13/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/14/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/14/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/15/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/15/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/16/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/16/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/17/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/17/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/18/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/18/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/19/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/19/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/20/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/20/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/21/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/21/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/22/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/22/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/23/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/23/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/24/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/24/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/25/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/25/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/26/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/26/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/27/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/27/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/28/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/28/avatar"></a>
<a href="https://opencollective.com/vcr/sponsor/29/website" target="_blank"><img src="https://opencollective.com/vcr/sponsor/29/avatar"></a>
