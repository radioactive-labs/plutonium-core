# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::MatcherTest < ActiveSupport::TestCase
  M = Plutonium::Rbac::Matcher

  test "exact key" do
    assert M.grants?(Set["post.read"], "post.read")
    refute M.grants?(Set["post.read"], "post.create")
  end

  test "global wildcard grants everything" do
    assert M.grants?(Set["*"], "blogging/post.salary.read")
    assert M.grants?(Set["*"], "*")
  end

  test "resource wildcard grants that resource only" do
    assert M.grants?(Set["blogging/post.*"], "blogging/post.publish")
    assert M.grants?(Set["blogging/post.*"], "blogging/post.salary.write")
    refute M.grants?(Set["blogging/post.*"], "comment.read")
  end

  test "granting a wildcard needs an equal or broader wildcard" do
    refute M.grants?(Set["post.read", "post.create"], "post.*")
    assert M.grants?(Set["post.*"], "post.*")
    refute M.grants?(Set["post.*"], "*")
  end
end
