classdef IrreducibleLaws < replab.Laws

    properties
        irreducible % Irreducible decomposition
        M % d x d matrices of the real/complex relevant field
    end

    methods

        function self = IrreducibleLaws(irreducible)
            self.irreducible = irreducible;
            d = self.irreducible.dimension;
            self.M = replab.domain.Matrices(irreducible.parent.field, d, d);
        end

        function law_decomposes_entire_space_(self)
            U = self.irreducible.U;
            self.M.assertEqv(U' * U, eye(self.irreducible.parent.dimension));
        end

        function isotypicLaws = laws_isotypic_components(self)
            children = cell(1, self.irreducible.nComponents);
            for i = 1:self.irreducible.nComponents
                x = self.irreducible.component(i);
                if isa(x, 'replab.HarmonizedIsotypic')
                    children{1,i} = replab.HarmonizedIsotypicLaws(x);
                else
                    children{1,i} = replab.IsotypicLaws(x);
                end
            end
            isotypicLaws = replab.laws.Collection(children);
        end

    end

end
