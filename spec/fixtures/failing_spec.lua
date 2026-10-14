describe("a fixture that must fail", function()
    it("fails on purpose the first time", function()
        assert.equals(1, 2)
    end)

    it("fails on purpose the second time", function()
        assert.is_true(false)
    end)
end)
