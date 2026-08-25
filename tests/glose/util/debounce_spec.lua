local debounce = require "glose.util.debounce"

describe("glose.util.debounce", function()
  it("calls the wrapped fn only once after quiet period", function()
    local count = 0
    local fn = debounce(20, function()
      count = count + 1
    end)

    fn()
    fn()
    fn()

    vim.wait(200, function()
      return count > 0
    end)
    assert.equal(1, count)
  end)

  it("delivers the most recent arguments", function()
    local received
    local fn = debounce(20, function(v)
      received = v
    end)

    fn "a"
    fn "b"
    fn "c"

    vim.wait(200, function()
      return received ~= nil
    end)
    assert.equal("c", received)
  end)

  it("coalesces rapid bursts into a single invocation", function()
    local count = 0
    local fn = debounce(30, function()
      count = count + 1
    end)

    fn()
    vim.wait(10)
    fn()
    vim.wait(10)
    fn()

    vim.wait(200, function()
      return count > 0
    end)
    assert.equal(1, count)
  end)

  it("allows a second invocation after the first fires", function()
    local count = 0
    local fn = debounce(20, function()
      count = count + 1
    end)

    fn()
    vim.wait(100, function()
      return count == 1
    end)

    fn()
    vim.wait(100, function()
      return count == 2
    end)

    assert.equal(2, count)
  end)
end)
