class ChoreDefinition < ::ResourceDefinition
  # Lets the filtered-drop tests hide rows the way a real filter does, which is
  # how `move.index` is shown to be a claim about the VIEWPORT rather than about
  # the list acts_as_list is renumbering.
  search do |scope, query|
    scope.where("title LIKE ?", "%#{query}%")
  end

  # ── Mode B, verbatim from docs/reference/positioning.md ────────────────────
  #
  # The model owns nothing of Plutonium's positioning: no
  # Plutonium::Positioning::Model, no positioned_on. acts_as_list owns both the
  # column and the write; Plutonium only orders, routes and authorizes.
  #
  # This block is a COPY of the documented worked example and must stay one —
  # test/plutonium/resource/controllers/position_actions_acts_as_list_test.rb
  # drives it through POST <member>/reposition, so if the docs change and this
  # does not, the tests stop testing the docs.
  #
  # It anchors off the NEIGHBOURS rather than off `move.index`, because a Mode B
  # block receives the client's viewport verbatim: `move.index` counts the other
  # rows on the current PAGE, while insert_at addresses the whole scope group.
  # `insert_at(move.index + 1)` is therefore only ever right on an unfiltered
  # page 1 — the same test pins its exact failure numbers under pagination and
  # filtering so the documented warning cannot rot.
  position_on :position do |move|
    record = move.record

    target =
      if move.prev
        # Land immediately after prev. When the record is currently ABOVE prev,
        # removing it shifts prev up one, so prev's own rank is already the slot.
        (record.position > move.prev.position) ? move.prev.position + 1 : move.prev.position
      elsif move.next
        # Nothing visible above, but rows may still sit above off-page. Land
        # immediately before next, mirrored: when the record is currently above
        # next, removing it shifts next up one.
        (record.position < move.next.position) ? move.next.position - 1 : move.next.position
      else
        1 # the only row in the list
      end

    record.insert_at(target)
  end
end
