---
title: "Plutonium drag-to-reorder: what happens when fractional ordering runs out of room"
titleTemplate: "Plutonium Blog"
date: 2026-09-21
description: Halving the gap between two decimals works about twenty times. The interesting engineering is in the twenty-first.
author: Stefan Froelich
tags: [positioning, rails, database]
draft: true
---

# Plutonium drag-to-reorder: what happens when fractional ordering runs out of room

<BlogMeta />

The appeal of fractional ordering is obvious once you have written the alternative. To drop a row between two others, you write the midpoint of their positions. One row changes. No `UPDATE … SET position = position + 1` sweeping the table, no lock contention, no re-sending a list to the client.

```ruby
Plutonium::Positioning.position_between(1.0, 3.0)   # => 2.0
Plutonium::Positioning.position_between(nil, 5.0)   # => 4.0  (prepend)
Plutonium::Positioning.position_between(5.0, nil)   # => 6.0  (append)
```

The part people skip is that midpoints are a finite resource, and running out is a correctness problem rather than a performance one.

## Twenty drops into the same slot

Every insert into the *same* gap halves it: `1.0`, then `0.5`, then `0.25`. After about twenty consecutive drops between the same two neighbours, the gap is below `1e-6`. Keep going and you are asking the database to distinguish decimals it cannot store, at which point two rows share a position and your ordering is whatever the query planner feels like today.

Twenty sounds like a lot until you picture a user tidying a backlog, repeatedly dragging things to the same spot near the top.

## The threshold and the column

Two numbers hold this together, and they are related in a way that is easy to get wrong.

`EPSILON` is `1e-6`. When a gap drops below it, `reposition!` rebalances **just that scope group**: it renumbers the group's rows to fresh integers (`1.0, 2.0, 3.0, …`) in current-position order, inside a transaction, reloads the two neighbours, and writes the new midpoint. Other scope groups are untouched, so rebalancing a "Doing" column does not disturb "Done".

The column is `decimal(16, 8)`, which the `t.position` migration helper emits for you:

```ruby
create_table :tasks do |t|
  t.position        # decimal :position, precision: 16, scale: 8
end
```

The relationship: the column needs **at least two more decimal places than `EPSILON`**. Rebalancing triggers at `1e-6`, so a `scale: 8` column still has room to write that final midpoint cleanly before the rebalance happens. Give it `scale: 6` and the last subdivision before a rebalance can round into a neighbour and momentarily collide, which is a rare, data-dependent bug that will not reproduce on your machine.

This is why the helper exists. `t.position` is not sugar for `decimal :position`; it is the framework refusing to let you pick a scale that appears to work.

## The bit I did not expect to matter

`reposition!` returns a `Plutonium::Positioning::Result`, and the useful thing on it is `rebalanced?`: did rows *other than this one* move?

That single boolean decides the HTTP response. If nothing else moved, the client's optimistic update is already correct and the endpoint answers `204 No Content`. If a rebalance happened, every row in that group has a new number, the client's model of the world is stale, and the endpoint sends the whole collection back.

Without it you have two bad options: always return the collection, and pay a full re-render on every drag; or never return it, and let the client drift out of sync on the one drag in twenty that renumbers everything. The flag turns a rare event into a cheap one instead of taxing the common case for it.

## End moves never rebalance

A drop at either end passes a `nil` neighbour, and `position_between` answers with `prev + 1` or `next - 1`. Integers, always room, no halving. So "drag to the top" and "drag to the bottom", which are the two most common gestures in any list, cannot trigger a rebalance at all.

That is a nice property that falls out of the arithmetic rather than being designed in, and it means the pathological case requires deliberately dropping into the same interior gap twenty times.

## The general lesson

Fractional ordering is usually presented as a trick: store decimals, write midpoints, done. It is a good trick. But it comes with a resource that depletes, and a system that uses it without a rebalance path is not simpler, it is unfinished. It just fails later, on a table someone has been reordering for two years, in a way that looks like the database losing your data.

The work is not the midpoint. It is knowing when you have run out of them, having somewhere to put the rows when you do, and telling the client which of those two things just happened.
