function test_suite = valueTest()
    try
        test_functions = localfunctions();
    catch
    end
    initTestSuite;
end

function test_cases
    % We do some sanity checks
    matrix = replab.CommutantVar.fromPermutations({[2 3 4 5 1]});
    
    assert(norm(isnan(value(matrix))-1) == 0);
end
