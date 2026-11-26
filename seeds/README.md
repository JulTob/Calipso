# Start lists

Each file here is a list of addresses where a training run can start: one
address per line, and lines that start with `#` are notes.

Give the name of a list instead of an address:

    calipso_crawl brains/es.zmb seeds/wikipedia_es.txt under=/wiki/ pages=500

or, in the "Train a brain" workflow on GitHub, write `seeds/wikipedia_es.txt`
in the *address* box and `/wiki/` in the *under* box.

How the list is used while the robot runs:

1. Every address of the file goes into the waiting list, in order.
2. The robot takes the first address out, reads the page, and puts the new
   links it found at the end of the list.
3. Before an address gets a seat in the list, the rules of its site
   (`robots.txt`) are asked. An address those rules close never waits.

**One list, one site, one language, one brain.** The robot only follows links
that stay on the site of the page they are in, so a list for `es.wikipedia.org`
grows a Spanish brain and never wanders into another language.
