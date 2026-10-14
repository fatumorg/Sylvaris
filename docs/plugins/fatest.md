# FaTest

Internet speed tests with [FaTest](https://github.com/fatumorg/FaTest) 2.1 or newer, which must be on your `PATH`.

Turn it on in SylSettings › Plugins or with `sylvaris plugins enable fatest`, then:

```sh
sylvaris fatest          # open the panel
sylvaris fatest run      # start a test
sylvaris fatest stop     # cancel one
sylvaris fatest history  # past results as JSON (also: state)
```

The panel shows the server and ping, then live download and upload speeds. Results go into FaTest's own history (`~/.fatest_history.json`), so runs from the terminal show up in the panel and the other way round. SylSettings › FaTest sets the default country or server through `fatest config`, which the `fatest` command uses as well.

SylCenter can get a FaTest tile (`center.extra`): the icon starts or stops a test and the tile opens the panel. `placement.fatest` sets where the panel opens.
