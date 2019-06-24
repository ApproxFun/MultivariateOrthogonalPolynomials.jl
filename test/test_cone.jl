using ApproxFun, MultivariateOrthogonalPolynomials, StaticArrays, FillArrays, BlockArrays, Test
import ApproxFunBase: checkpoints, plan_transform!, fromtensor
import MultivariateOrthogonalPolynomials: rectspace, totensor, duffy2legendreconic!, legendre2duffyconic!, c_plan_rottriangle, plan_transform,
                        c_execute_tri_hi2lo, c_execute_tri_lo2hi, duffy2legendrecone_column_J!, duffy2legendrecone!, legendre2duffycone!,
                        duffy2legendreconic!, ConicTensorizer, pointsize


@testset "Conic" begin
    @testset "tensorizer derivation" begin
        A = [1 2 3 5 6;
             4 7 8 0 0;
             9 0 0 0 0] 
        B = PseudoBlockArray(A, Ones{Int}(3), [1; Fill(2,2)])

        a = Vector{eltype(A)}()
        for N = 1:nblocks(B,2), K=1:N
            append!(a, vec(B[Block(K,N-K+1)]))
        end

        @test a == fromtensor(ConicTensorizer(),A) == fromtensor(LegendreConic(),A) == 1:9

        N = isqrt(length(a))
        M = 2N-1
        Ã = zeros(eltype(a), N, M)
        B = PseudoBlockArray(Ã, Ones{Int}(3), [1; Fill(2,2)])
        k = 1
        for N = 1:nblocks(B,2), K=1:N
            V = view(B, Block(K,N-K+1))
            for j = 1:length(V)
                V[j] = a[k]
                k += 1
            end
        end
        @test Ã == totensor(ConicTensorizer(),a) == totensor(LegendreConic(),a) == A
    end

    @testset "DuffyConic" begin
        f = Fun((t,x,y) -> 1, DuffyConic(), 10)
        @test f.coefficients ≈ [1; zeros(ncoefficients(f)-1)]
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ 1

        f = Fun((t,x,y) -> t, DuffyConic(), 10)
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ sqrt(0.1^2+0.2^2)

        f = Fun((t,x,y) -> x, DuffyConic(), 10)

        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ 0.1

        f = Fun((t,x,y) -> exp(cos(t*x)*y), DuffyConic(), 1000)
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ exp(cos(sqrt(0.1^2+0.2^2)*0.1)*0.2)

        f = Fun((t,x,y) -> exp(cos(t*x)*y), DuffyConic())
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ exp(cos(sqrt(0.1^2+0.2^2)*0.1)*0.2)

        m,ℓ = (1,1)
        f = (txy) -> ((t,x,y) = txy;  θ = atan(y,x); Fun(NormalizedJacobi(0,2m+1,Segment(1,0)),[zeros(ℓ);1])(t) * 2^m * t^m * cos(m*θ))
        g = Fun(f, DuffyConic())
        t,x,y = sqrt(0.1^2+0.2^2),0.1,0.2
        @test g(t,x,y) ≈ f((t,x,y))
    end

    @testset "Legendre<>DuffyConic" begin
        for k = 0:10
            a = [zeros(k); 1.0; zeros(5)]
            F = totensor(rectspace(DuffyConic()), a)
            F = pad(F, :, 2size(F,1)-1)
            T = eltype(a)
            P = c_plan_rottriangle(size(F,1), zero(T), zero(T), zero(T))
            @test legendre2duffyconic!(P, duffy2legendreconic!(P, copy(F))) ≈ F

            b = coefficients(a, LegendreConic(), DuffyConic())
            @test a ≈ coefficients(b, DuffyConic(), LegendreConic())[1:length(a)]
        end
    end

    @testset "LegendreConicPlan" begin
        p = points(LegendreConic(),10)
        @test length(p) == 6
        v = fill(1.0,length(p))
        n = length(v)
        N = (1 + isqrt(1+8n)) ÷ 4
        M = 2N-1
        D = plan_transform!(rectspace(DuffyConic()), reshape(v,N,M))
        N,M = D.plan[1][2],D.plan[2][2]
        V=reshape(v,N,M)
        @test D*V ≈ [[1 zeros(1,2)]; zeros(1,3)]
        T = Float64
        P = c_plan_rottriangle(N, zero(T), zero(T), zero(T))
        duffy2legendreconic!(P,V)
        @test V ≈ [[1 zeros(1,2)]; zeros(1,3)]
        @test_broken fromtensor(DuffyConic(), V) ≈ [1; Zeros(5)]

        v = fill(1.0,length(p))
        @test plan_transform(LegendreConic(),v)*v ≈ [1; Zeros(3)]
        @test v == fill(1.0,length(p))
    end

    @testset "LegendreConic" begin
        f = Fun((t,x,y) -> 1, LegendreConic(), 10)
        @test f.coefficients ≈ [1; zeros(ncoefficients(f)-1)]
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ 1

        f = Fun((t,x,y) -> t, LegendreConic(), 10)
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ sqrt(0.1^2+0.2^2)
        f = Fun((t,x,y) -> 1+t+x+y, LegendreConic(), 10)
        @test f(sqrt(0.1^2+0.2^2),0.1,0.2) ≈ 1+sqrt(0.1^2+0.2^2)+0.1+0.2

        @time Fun((t,x,y) -> 1+t+x+y, LegendreConic(), 1000)

        f = Fun((t,x,y) -> exp(x*cos(t+y)), LegendreConic())

        for (m,ℓ) in ((0,0), (0,1), (0,2), (1,1), (1,2), (2,2))
            f = (txy) -> ((t,x,y) = txy;  θ = atan(y,x); Fun(NormalizedJacobi(0,2m+1,Segment(1,0)),[zeros(ℓ);1])(t) * 2^m * t^m * cos(m*θ))
            g = Fun(f, LegendreConic())
            t,x,y = sqrt(0.1^2+0.2^2),0.1,0.2
            @test g(t,x,y) ≈ f((t,x,y))
        end
    end
end

@testset "Cone" begin
    @testset "rectspace" begin
        rs = rectspace(DuffyCone())
        @test points(rs,10) isa Vector{SVector{3,Float64}}
        @test_broken @inferred(checkpoints(rs))
        @test checkpoints(rs) isa Vector{SVector{3,Float64}}
    end

    @testset "ConeTensorizer" begin
        ts = MultivariateOrthogonalPolynomials.ConeTensorizer()
        @test totensor(ts,1:10) == [1 2 3 5 6 7; 4 8 9 0 0 0; 10 0 0 0 0 0]
    end

    @testset "DuffyCone" begin
        p = points(DuffyCone(), 10)
        @test p isa Vector{SVector{3,Float64}}
        P = plan_transform(DuffyCone(), Vector{Float64}(undef, length(p)))
        
        @test P * fill(1.0, length(p)) ≈ [1/sqrt(2); Zeros(55)] ≈ [Fun((x,y) -> 1, ZernikeDisk()).coefficients; Zeros(55)]

        f = Fun((t,x,y) -> 1, DuffyCone(), 10)
        @test f.coefficients ≈ [1/sqrt(2); Zeros(55)]
        @test f(0.3,0.1,0.2) ≈ 1

        f = Fun((t,x,y) -> t, DuffyCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.3

        f = Fun((t,x,y) -> x, DuffyCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.1

        f = Fun((t,x,y) -> y, DuffyCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.2

        f = Fun((t,x,y) -> exp(cos(t*x)*y), DuffyCone(), 2000)
        @test f(0.3,0.1,0.2) ≈ exp(cos(0.3*0.1)*0.2)

        f = Fun((t,x,y) -> exp(cos(t*x)*y), DuffyCone())
        @test f(0.3,0.1,0.2) ≈ exp(cos(0.3*0.1)*0.2)
    end

    @testset "TriTransform" begin
        m = 1
        p = Fun(NormalizedJacobi(0,2m+2,0..1), [1])
        q = Fun(x -> p(x)*(1-x)^m * 2^m, NormalizedJacobi(0,2,0..1))
        F = [zeros(2)  q.coefficients]
        F = pad(F, :, 2size(F,1)-1)
        T = Float64
        P = c_plan_rottriangle(size(F,1), zero(T), zero(T), one(T))
        c_execute_tri_lo2hi(P, F)
        @test F ≈ (B = zeros(size(F)); B[1,m+1] = 1; B)
    end

    @testset "Legendre<>DuffyCone" begin
        for (m,k,ℓ) in ((0,0,0), (0,0,1), (0,0,2), (1,0,0), (1,0,1), (1,1,0), (1,1,1), (1,1,2))
            Y = Fun(ZernikeDisk(), [Zeros(sum(1:m)+k); 1])
            f = (txy) -> ((t,x,y) = txy;  θ = atan(y,x); Fun(NormalizedJacobi(0,2m+2,Segment(1,0)),[zeros(ℓ);1])(t) * 2^m * t^m * Y(x/t,y/t))
            g = Fun(f, DuffyCone())
            a = g.coefficients
            F = totensor(rectspace(DuffyCone()), a)
            for j = 1:size(F,2)
                F[:,j] = coefficients(F[:,j], NormalizedJacobi(0,1,Segment(1,0)), NormalizedJacobi(0,2,Segment(1,0)))
            end

            T = eltype(a)
            P = c_plan_rottriangle(size(F,1), zero(T), zero(T), one(T))

            Fc = Matrix{Float64}(undef,size(F,1),size(F,1))
            for J = 1:size(F,2)
                duffy2legendrecone_column_J!(P, Fc, F, J)
            end

            @test F ≈ (B = zeros(size(F)); B[ℓ+1,sum(1:m)+k+1] = 1; B)
        end
        for k = 0:10
            a = [zeros(k); 1.0; zeros(5)]
            F = totensor(rectspace(DuffyCone()), a)
            F = pad(F, :, 2size(F,1)-1)
            
            T = eltype(a)
            P = c_plan_rottriangle(size(F,1), zero(T), zero(T), one(T))
            
            @test legendre2duffycone!(P, duffy2legendrecone!(P, copy(F))) ≈ F

            b = coefficients(a, LegendreCone(), DuffyCone())
            @test a ≈ coefficients(b, DuffyCone(), LegendreCone())[1:length(a)]
        end
    end
    

    @testset "LegendreConePlan" begin
        for N = 1:10
            n = N*sum(1:N)
            @test round(Int, 1/6*(1 + 1/(1 + 54n + 6sqrt(3)sqrt(n + 27n^2))^(1/3) + (1 + 54n + 6sqrt(3)sqrt(n + 27n^2))^(1/3)), RoundUp)
        end
        p = points(LegendreCone(),10)
        @test length(p) == 12 == 2*2*3
        v = fill(1.0,length(p))
        n = length(v)
        M,N,O = pointsize(Cone(),n)
        

        D = plan_transform!(rectspace(DuffyCone()), reshape(v,N,M))
        N,M = D.plan[1][2],D.plan[2][2]
        V=reshape(v,N,M)
        @test D*V ≈ [[1/sqrt(2) zeros(1,5)]; zeros(2,6)]
        T = Float64
        P = c_plan_rottriangle(N, zero(T), zero(T), zero(T))
        duffy2legendrecone!(P,V)
        @test V ≈ [[1/sqrt(2) zeros(1,5)]; zeros(2,6)]
        @test fromtensor(LegendreCone(), V) ≈ [1/sqrt(2); Zeros(55)]

        v = fill(1.0,length(p))
        P = plan_transform(LegendreCone(),v)
        @test P*v ≈ [1/sqrt(2); Zeros(55)]
        @test v == fill(1.0,length(p))

        p = points(LegendreCone(),20)    
        v = fill(1.0,length(p))
        P = plan_transform(LegendreCone(),v)
    

        for (m,k,ℓ) in ((0,0,0), )
            Y = Fun(ZernikeDisk(), [Zeros(sum(1:m)+k); 1])
            f = (txy) -> ((t,x,y) = txy;  θ = atan(y,x); Fun(NormalizedJacobi(0,2m+2,Segment(1,0)),[zeros(ℓ);1])(t) * 2^m * t^m * Y(x,y))
            g = Fun(f, LegendreCone(),20)
            t,x,y = 0.3,0.1,0.2
            @test g(t,x,y) ≈ f((t,x,y))
        end
    end

    @testset "LegendreCone" begin
        f = Fun((t,x,y) -> 1, LegendreCone(), 10)
        @test f.coefficients ≈ [1; zeros(ncoefficients(f)-1)]
        @test f(0.3,0.1,0.2) ≈ 1

        f = Fun((t,x,y) -> t, LegendreCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.3
        f = Fun((t,x,y) -> x, LegendreCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.1
        f = Fun((t,x,y) -> y, LegendreCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 0.2
        f = Fun((t,x,y) -> 1+t+x+y, LegendreCone(), 10)
        @test f(0.3,0.1,0.2) ≈ 1+0.3+0.1+0.2
        f = Fun((t,x,y) -> 1+t+x+y, LegendreConic(), 1000)
        @test f(0.3,0.1,0.2) ≈ 1+0.3+0.1+0.2
        @test ncoefficients(f) == 1771
    end
end

