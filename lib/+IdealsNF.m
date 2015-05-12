//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
//    +Ideals Package 
//    J. Guardia, J. Montes, E. Nart 
//    July 2012
//    (C) 2012 J. Guardia, J. Montes, E. Nart
//    Distributed under the terms of the GNU General Public License 
//    http://www.gnu.org/licenses/gpl.txt  
/////////////////////////////////////////////////////////////////////////////////////////
//    Routines Inversionloop, pAdicFactors, Cancel, SFL and SFLInitialize 
//    in collaboration with S. Pauli
/////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////

declare verbose montestalk, 4;
declare attributes FldNum: 
    pBasis, Discriminant, FactorizedDiscriminant, FactorizedPrimes, IntegralBasis,
LocalIndex, IndexPrimeFactors, PrimeIdeals, TreesIntervals;
			    
IdealRecord:=recformat<
Parent: FldNum,
IsIntegral: BoolElt,
IsPrime: BoolElt,
Factorization: SeqEnum,
FactorizationString:  MonStgElt,
Generators: SeqEnum , 
IntegerGenerator: Integers(),
Generator: FldNumElt,
Position: Integers(),        /* only for prime ideals */  
Type: SeqEnum,              /* only for prime ideals */
e: Integers(),              /* only for prime ideals */
f: Integers(),              /* only for prime ideals */
exponent: RngIntElt,        /* only for prime ideals */
LocalGenerator: FldNumElt,  /* only for prime ideals */
LogLG: ModTupRngElt,        /* only for prime ideals */
CrossValues: SeqEnum,      /* only for prime ideals */
Phiadic: List,       /* only for prime ideals */
sfl: SeqEnum            /* only for prime ideals */
>;

TypeLevel:=recformat<
Phi: RngUPolElt,
V: Integers(),
h: Integers(),
e: Integers(),
f: Integers(),
prode: Integers(),  /* e1*...*e(k-1) */
prodf: Integers(),  /* f1*...*f(k-1) */
invh: Integers(),
slope,
psi: RngUPolElt,
Fq: FldFin,
FqY:RngUPol,
z: FldFinElt,
omega: Integers(),
cuttingslope: Integers(),
Refinements: List, 
logPi: ModTupRngElt,
logPhi: ModTupRngElt,
logGamma: ModTupRngElt
>;

OkutsuFrameLevel := recformat<
    degree: RngIntElt,
    index: RngIntElt,
    values: List,
    polynomial: RngUPolElt
>;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic AdaptPrecision(Zp,pol,llista) -> RngUPolElt
{}           

precpol:=Precision(Coefficients(pol)[1]);
ppol:=ChangePrecision(pol,Zp`DefaultPrecision);
if Zp`DefaultPrecision gt precpol and precpol lt Ceiling(Log(Prime(Zp),1073741824)) then
    ll:=Coefficients(ppol);
    for i in llista do 
	ll[i]-:=UniformizingElement(Zp)^precpol;
    end for;
    ppol:=PolynomialRing(Zp)!ll;
end if;
return ppol;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Cancel(poly,vden: QUO:=true)->RngUPolElt,RngIntElt
{Cancell the powers of p in the numerator and denominator of
the fraction poly/p^vden, returning a polynomial outpoly and 
an exponent outputvden such that outpoly/p^outvden=poly/p^vden.}

if poly eq 0 then
    return poly,0;
end if;
cancel:=Min([vden,Min([Valuation(a):a in Eltseq(poly)])]);
Zp:=CoefficientRing(poly);
num:=poly div UniformizingElement(Zp)^cancel;
if not QUO then
    ChangePrecision(~num,GetPrecision(Zp));
end if;
return num,vden-cancel;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

intrinsic CompensateValue(~K,p,tree,exponents,~beta)
{tree is an interval [i..j] inside [1..#K`PrimeIdeals[p]] and exponents is a sequence of integers of length #tree.
The output is a power of the greatest common phi-polynomial of the tree, such that v_P >= exponents[P] for all P in the tree}

if &and[x le 0: x in exponents] then
    beta:=PolynomialRing(Integers())!1;
    return;
end if;
level:=0;
phi:=0;
Values:=0;
GCPhi(~K,p,tree,~level,~phi,~Values);
mx:=Max([exponents[k]/Values[k]: k in [1..#tree]]);
if mx le 1 and #tree eq 1 then
    M:=Ceiling(exponents[1]/K`PrimeIdeals[p,tree[1]]`e);
    beta:=phi mod p^M;
else
    beta:=phi^Ceiling(mx);
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////


intrinsic Construct(i,~type,p,respol,point,~Ppol)
{This routine constructs a polynomial Ppol with integer coefficients such that: 
deg Ppol<m_i+1 and y^nu*R_i(Ppol)(y)=respol(y), where nu=ord_y(respol).
The non-negative integers s,u are the coordinates of the left endpoint of a segment of slope -type[i]`slope supporting N_i(Ppol).
}

require i le #type: "the first input is too large";
require Degree(respol) lt type[i]`f: "the degree of the 3rd argument is too large"; 
s:=point[1];
u:=point[2];
require u+s*type[i]`slope ge type[i]`f*(type[i]`e*type[i]`V+type[i]`h): "the point (s,u) is too low";
var:=type[i]`Phi^type[i]`e;
Ppol:=0;
if i eq 1 then
    height:=u-Degree(respol)*type[i]`h;
    for a in Reverse(Coefficients(respol)) do
	lift:=PolynomialRing(Integers())!Eltseq(a,PrimeField(type[1]`Fq)); 
	Ppol:=Ppol*var+lift*p^height;
	height:=height+type[1]`h;
    end for; 
else	
    step:=type[i]`e*type[i]`V+type[i]`h;
    newV:=u-Degree(respol)*step-s*type[i]`V;
    im1:=i-1;
    for a in Reverse(Coefficients(respol)) do
	Pj:=0;
	if a ne 0 then
	    txp,sa:=Quotrem(type[im1]`invh*newV,type[im1]`e);
	    ua:=(newV-sa*type[im1]`h) div type[im1]`e; 
	    newrespol:=type[im1]`FqY!Eltseq(a*type[i]`z^txp,type[im1]`Fq);
	    Construct(im1,~type,p,newrespol,[sa,ua],~Pj);
	end if;
	Ppol:=Ppol*var+Pj;
	newV:=newV+step;
    end for;
end if;        
Ppol:=Ppol*type[i]`Phi^s;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

intrinsic ConvertLogs(~type,log,~class)
{The class mod P of the product of p^log[1]Phi_1^log[2] ... Phi_i^log[i+1], where P 
is the prime ideal given by type.
}

vector:=log;
z:=0;
class:=PrimeField(type[1]`Fq)!1;
for i:=Degree(vector)-1 to 1 by -1 do
    ti:=vector[i+1] div type[i]`e;
    Z(~type,i,~z);
    class*:=z^ti;
    vector:=vector-ti*type[i]`logGamma;
    vector:=Vector(Remove(Eltseq(vector),Degree(vector)));
end for;
end intrinsic;

///////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic CrossValues(~K,p)
{Compute the values of the attribue P`CrossValues for all prime ideals P 
in K`PrimeIdeals[p].}

for tree in K`TreesIntervals[p] do
    position:=tree[1]-1;
    Mat:=Matrix(Rationals(),#tree,#tree,[]);
    for j:=1 to #tree-1 do
	t1:=position+j;
	m1:=Degree(K`PrimeIdeals[p,t1]`Type[#K`PrimeIdeals[p,t1]`Type]`Phi);
	for k:=j+1 to #tree do
	    t2:=position+k;
	    inc:=0;
	    IndexOfCoincidence(~K`PrimeIdeals[p,t1]`Type,~K`PrimeIdeals[p,t2]`Type,~inc,p);
	    Ref1:=Append(K`PrimeIdeals[p,t1]`Type[inc]`Refinements,[* K`PrimeIdeals[p,t1]`Type[inc]`Phi,K`PrimeIdeals[p,t1]`Type[inc]`slope *]);
	    Ref2:=Append(K`PrimeIdeals[p,t2]`Type[inc]`Refinements,[* K`PrimeIdeals[p,t2]`Type[inc]`Phi,K`PrimeIdeals[p,t2]`Type[inc]`slope *]);
	    minlength:=Min(#Ref1,#Ref2);
	    ii:=2;
	    while ii le minlength and Ref1[ii,1] eq Ref2[ii,1] do 
		ii+:=1;    
	    end while;
	    minslope:=Min([Ref1[ii-1,2],Ref2[ii-1,2]]);
	    entry:=(K`PrimeIdeals[p,t1]`Type[inc]`V+minslope)/(K`PrimeIdeals[p,t1]`Type[inc]`prode*Degree(K`PrimeIdeals[p,t1]`Type[inc]`Phi));
	    Mat[k,j]:=Degree(K`PrimeIdeals[p,t2]`Type[#K`PrimeIdeals[p,t2]`Type]`Phi)*entry;
	    Mat[j,k]:=m1*entry;
	end for;
    end for;
    for t in tree do
	K`PrimeIdeals[p,t]`CrossValues:=RowSequence(Mat)[t-position];
    end for;
end for;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

intrinsic CRT(elements::SeqEnum[FldNumElt],ideals::SeqEnum[Rec])->FldNumElt
{
Compute  x congruent  to elements[j] mod ideals[j] for every j.
Integrality of the given elements is not checked!
}
r:=#ideals;
require r eq #elements: "The two lists must have the same length";
if r eq 0 then return 0; end if;
if r eq 1 then return elements[1]; end if;
K:=Parent(elements[1]);
require &and[x in K: x in elements]: "Elements should belong to the same number field";
//require &and[IsIntegralM(x): x in elements]: "Elements should all be integral";
require &and[K eq x`Parent: x in ideals]: "The number field of ideals and elements should be the same";
require &and[IsIntegral(x): x in ideals]: "Ideals should be all integral";

ids:=[x^1: x in ideals]; // We assure they are IdealRecords
S:={ };
PrimeNumbers:={@ @};
total:=0;
for i:=1 to r do
    list:=[Prune(x): x in ids[i]`Factorization];
    total+:=#list;
    S join:=Set(list);
    PrimeNumbers join:={@ x[1]: x in list @};
end for;
require #S eq total: "Ideals must be pairwise coprime.";
if #PrimeNumbers eq 0 then return 0; end if;
ListMaxExps:=[];
MaxMaxExps:=[];
Allcp:=[];
cps:=0;
for p in PrimeNumbers do
    cp:=[K!0: i in [1..r]];
    nprimes:=#K`PrimeIdeals[p];
    exponents:=[0: i in [1..nprimes]];
    indices:=exponents;
    MaxExps:=[0: i in [1..r]];
    for i in [1..r] do
	list:=[x:x in ids[i]`Factorization| x[1] eq p];
	if #list gt 0 then 
	    MaxExps[i]:=Ceiling(Max([x[3]/K`PrimeIdeals[p,x[2]]`e: x in list]));
	    for x in list do
		exponents[x[2]]:=x[3];
		indices[x[2]]:=i;
	    end for;
	end if;
    end for;
    Append(~ListMaxExps,MaxExps);
    Append(~MaxMaxExps,p^(Max(MaxExps)));
    LocalCRT(~K,p,exponents,~cps);
    for i:=1 to r do
        list:=[cps[k]: k in [1..nprimes]|indices[k] eq i];
	if #list gt 0 then 
	    cp[i]:=&+list; 
	end if;
    end for;
    Append(~Allcp,cp);
end for;
solution:=K!0;
for i:=1 to r do
    ci:=K!0;
    for k in [1..#PrimeNumbers] do
	   zeros:=[0: i in [1..#PrimeNumbers]] ;
	   zeros[k]:=1;
	   list:=MaxMaxExps;
	   list[k]:=PrimeNumbers[k]^ListMaxExps[k,i];
	   ci+:=Allcp[k,i]*CRT(zeros,list);
     end for;
     solution+:=ci*elements[i];
end for;
den:=Denominator(solution);
module:=den*&*MaxMaxExps;
num:=Eltseq(Numerator(solution),Integers());
num:=PolynomialRing(Integers())![x mod module: x in num];
//solution:=Evaluate(num,K.1)/den;    
solution:=K!Eltseq(num)/den;    
return solution;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

intrinsic Different(~P,~different)
{Valuation of the different ideal of the local extension of Qp given 
by the p-adically irreducible polynomial represented by the given prime ideal P.}
e:=P`Type[#P`Type]`prode;

p:=P`IntegerGenerator;
mu:=0;
if #P`Type gt 1 then 
    nu:=&+[P`Type[j]`slope/P`Type[j]`prode: j in [1..#P`Type-1]];
    mu:=(P`Type[#P`Type]`V/e)-nu;
end if;
ve:=Valuation(e,p);
rho:=0;
if ve ne 0 then 
    SFL(~P,e*ve);
    val:=0;
    dev:=[* *];
    der:=Derivative(P`Type[#P`Type]`Phi);
    Value(#P`Type,~P`Type,~der,p,~dev,~val);
    rho:=val-e*mu;
end if;
different:=e-1+rho;
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic EqualizeLogs(~log1,~log2)
{Add zeros to the shorter first list to achieve the same length as the second list.}

d:=Degree(log1)-Degree(log2);
if d ne 0 then
    tail:=[0: i in [1..Abs(d)]];
    if d gt 0 then
	log2:=Vector(Eltseq(log2) cat tail);
    else
	log1:=Vector(Eltseq(log1) cat tail);
    end if;
end if;
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic FaithfulpAdicConversion(pol,p) -> RngUPolElt, SeqEnum
{}

coeffs:=Coefficients(pol);
negativecoeffs:=[i : i in [1..#coeffs] | coeffs[i] lt 0];
Zp:=pAdicRing(p);
Zp`DefaultPrecision:=Ceiling(Log(p,Max([Abs(a): a in coeffs])))+2;
return PolynomialRing(Zp)!pol, negativecoeffs;
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic GCPhi(~K,p,tree,~node,~phi,~Values)
{The routine stores in phi the greatest common phi-polynomial of the tree.
Values is the sequence of all v_P(phi(theta)) for P in the tree.  
node is the level of phi}

i:=0;
node:=#K`PrimeIdeals[p,tree[1]]`Type;
if #tree gt 1 then
    for k in Exclude(tree,tree[1]) do
	IndexOfCoincidence(~K`PrimeIdeals[p,tree[1]]`Type,~K`PrimeIdeals[p,k]`Type,~i);
	if node gt i then
	    node:=i;
	end if;
    end for;
end if;
level:=K`PrimeIdeals[p,tree[1]]`Type[node];
if #level`Refinements eq 0 then
    phi:=level`Phi;
else
    phi:=level`Refinements[1,1];
end if;
Values:=[];
for i in tree do
    leveli:=K`PrimeIdeals[p,i]`Type[node];
    if #leveli`Refinements eq 0 then
	firstslope:=leveli`slope;
    else
	firstslope:=leveli`Refinements[1,2];	
    end if;
Append(~Values,(K`PrimeIdeals[p,i]`e div level`prode)*(level`V+firstslope));
end for;
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Generators(K,p)
{Compute the generators of the prime ideals in K above the rational prime p.}

Montes(K,p);
if &and[assigned P`Generator: P in K`PrimeIdeals[p]] then
    return;
end if;
nprimes:=#K`PrimeIdeals[p];
if nprimes eq 1 then 
    K`PrimeIdeals[p,1]`Generator:=K`PrimeIdeals[p,1]`LocalGenerator;
    return;
end if;
for tree in K`TreesIntervals[p] do
    pos:=tree[1];
    if #tree eq 1 and K`PrimeIdeals[p,pos]`e eq 1 then
	level:=K`PrimeIdeals[p,pos]`Type[1];
//	gen:=Evaluate(level`Phi,K.1);
	gen:=K!Eltseq(level`Phi);
	if level`slope gt 1 then 
	    gen+:=p;
	end if;
	K`PrimeIdeals[p,pos]`Generator:=gen;
    end if;
end for;
if &and[assigned P`Generator: P in K`PrimeIdeals[p]] then
    return;
end if;

//   Computation of the generators
bps:=0;
MultipliersGenerators(~K,p,~bps);
for i in [1..nprimes] do
    if not assigned K`PrimeIdeals[p,i]`Generator then
	gen:=K`PrimeIdeals[p,i]`LocalGenerator*bps[i];
	K`PrimeIdeals[p,i]`Generator:=gen+&+[bps[x]: x in Exclude([1..nprimes],i)];
    end if;
end for;

//Smaller size generators
for i in [1..nprimes] do
    numgen:=Numerator(K`PrimeIdeals[p,i]`Generator);
    dengen:=Denominator(K`PrimeIdeals[p,i]`Generator);
    val:=Valuation(dengen,p)+1;
    if K`PrimeIdeals[p,i]`e eq 1 then 
	val+:=1; 
    end if;
    numcoeffs:=[x mod p^val: x in Eltseq(numgen,Integers())];
    gcd:=GCD(numcoeffs);
    numcoeffs:=[x div gcd: x in numcoeffs];
//    gen:=Evaluate(PolynomialRing(Integers())!numcoeffs,K.1)/dengen;	
    gen:=K!numcoeffs/dengen;	
    if gen eq 1 then 
	gen:=K!p; 
    end if;
K`PrimeIdeals[p,i]`Generator:=gen;      
end for;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic IndexOfCoincidence(~t1,~t2,~i,p)
{ The index is 0 if t1,t2 belong to different trees. Otherwise, it is the least index such that the triplets 
(t1[i]`Phi,t1[i]`slope,t1[i]`psi) and (t2[i]`Phi,t2[i]`slope,t2[i]`psi) are different.
The types must correspond to different prime ideals.}

if t1[1]`Phi mod p ne t2[1]`Phi mod p then 
    i:=0;
end if;
i:=1;
while t1[i]`Phi eq t2[i]`Phi and t1[i]`slope eq t2[i]`slope and t1[i]`psi eq t2[i]`psi do
    i+:=1;
end while;	
end intrinsic;

intrinsic IndexOfCoincidence(t1::Rec, t2::Rec)-> RngIntElt
    { The index of coincidence of types t1 and t2. }

    require t1`IntegerGenerator eq t2`IntegerGenerator:
        "Types attached to difference prime numbers.";

    if t1`Type[1]`Phi mod t1`IntegerGenerator ne t2`Type[1]`Phi mod t1`IntegerGenerator then
        // These types don't have a common psi_0.
        index := 0;
    else
        index := 1;
        while t1`Type[index]`Phi eq t2`Type[index]`Phi and
                t1`Type[index]`slope eq t2`Type[index]`slope and
                t1`Type[index]`psi eq t2`Type[index]`psi do
            index +:= 1;
        end while;
    end if;

    return index;
end intrinsic;

intrinsic IndexOfCoincidence(t1::SeqEnum, t2::SeqEnum)-> RngIntElt
    { The index of coincidence of types t1 and t2. }

    i := 0;

    IndexOfCoincidence(~t1, ~t2, ~i);

    return i;
end intrinsic; // IndexOfCoincidence



intrinsic IndexOfCoincidence2(~t1,~t2,~i,p)
{the types must correspond to different prime ideals}

if t1[1]`Phi mod p ne t2[1]`Phi mod p then 
    i:=0;
else

i:=1;
while t1[i]`Phi eq t2[i]`Phi and t1[i]`slope eq t2[i]`slope and t1[i]`psi eq t2[i]`psi do
    i+:=1;
end while;	
end if;

end intrinsic;

intrinsic IndexOfCoincidence(t1::Rec, t2::Rec)-> RngIntElt
    { The index of coincidence of types t1 and t2. }

    i := 0;
    IndexOfCoincidence(~t1`Type, ~t2`Type, ~i, t1`IntegerGenerator);

    return i;
end intrinsic;

intrinsic IndexOfCoincidence(t1::SeqEnum, t2::SeqEnum)-> RngIntElt
    { }

    i := 0;
    IndexOfCoincidence(~t1, ~t2, ~i);

    return i;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic InitialPrimeIdeal(Pol,p,psi,power)-> Rec
{Initialize a prime IdealRecord with the given data. 
psi is a monic irreducible factor of Pol modulo p and power=ord_psi(Pol mod p)}

Zx:=PolynomialRing(Integers());
level:=rec<TypeLevel| 
Phi:=Zx!Coefficients(psi), V:=0, prode:=1, prodf:=Degree(psi), Fq:=ext<GF(p)|psi>,
omega:=power, cuttingslope:=0, Refinements:=[**], logPi:=Vector([1,0]), logPhi:=Vector([0,1])
>;
if level`prodf gt 1 then  
    mmm,nnn:=HasAttribute(level`Fq,"PowerPrinting");
    if mmm and nnn then 
	AssertAttribute(level`Fq, "PowerPrinting", false); 
    end if;
    level`z:=(level`Fq).1;
    AssignNames(~(level`Fq),["z" cat IntegerToString(0)]);
else
    level`z:=-Coefficient(psi,0);
end if;
level`FqY:=PolynomialRing(level`Fq);
AssignNames(~(level`FqY),["Y" cat IntegerToString(0)]);
Primeid:=rec<IdealRecord|
IntegerGenerator:=p, Type:=[level], Phiadic:=[* 0,0,0,0,0,0,0 *], sfl:=[0,0,0,0], exponent:=0
>;
return Primeid;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic IntegralBasis(K::FldNum)->SeqEnum
{Compute a basis  of the maximal order ZK of K and the discriminant of K.}

if not assigned K`IntegralBasis then 
    if not assigned K`FactorizedDiscriminant then
	K`FactorizedDiscriminant:=Factorization(Discriminant(DefiningPolynomial(K)));
    end if;
    K`IntegralBasis:=SIntegralBasis(K,[x[1]: x in K`FactorizedDiscriminant]);
end if;
return K`IntegralBasis;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Inversionloop(A,~xnum,~xden,phi,precision,Zp)
{Apply one iteration of the classical p-adic Newton method 
to find and approximation xnum/xden to the inverse of A.}

anum:=A[1];
aden:=A[2];
pi:=UniformizingElement(Zp);
zqq:=quo<Zp|pi^precision>;
piq:=UniformizingElement(zqq);
zqqt<t>:=PolynomialRing(zqq);
Phip:=zqqt!phi; 
xnum := zqqt!xnum;
x1num,x1den:=Cancel(2*piq^(xden+aden)-(zqqt!anum*xnum) mod Phip,xden+aden); 
xnum,xden:=Cancel((xnum*x1num) mod Phip, xden+x1den);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
intrinsic IsIntegralM(alpha::FldNumElt)->BoolElt
{True iff the algebraic number alpha is integral. It should be fasther than the Magma standard routine}
primes:=PrimeDivisors(Denominator(alpha));
for p in primes do
    Montes(Parent(alpha),p);
    for P in Parent(alpha)`PrimeIdeals[p] do
    	if PValuation(alpha,P) lt 0 then
	       return false;
	   end if;
    end for;
end for;
return true;
end intrinsic;

//////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic LastLevel(Phiadic,~omrep,slope,dev: Lastpsi:=false)
{This routine is called when a prime ideal is detected in the Montes algorithm. If the slope at the last level of the coresponding type is finite, this routine attaches certain data at the last level 
}

r:=#omrep`Type;
omrep`Type[r]`e:=1;
if r gt 1 then 
    nur:=&+[omrep`Type[j]`slope/omrep`Type[j]`prode: j in [1..r-1]]; 
    omrep`exponent:=Floor((omrep`Type[r]`V/omrep`Type[r]`prode)-nur);
end if;
omrep`Type[r]`slope:=slope;
omrep`Type[r]`h:=Integers()!slope;
omrep`Phiadic[1]:=Phiadic[1];
omrep`Phiadic[2]:=Phiadic[2];
if Lastpsi then
    psi:=0;
    ResidualPolynomial(r,~omrep`Type,omrep`IntegerGenerator,~dev,~psi);
    omrep`Type[r]`psi:=psi/LeadingCoefficient(psi);
    omrep`Type[r]`logGamma:=omrep`Type[r]`logPhi-omrep`Type[r]`h*omrep`Type[r]`logPi;
end if;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic Lift(class,P)->FldNumElt
{}

require IsPrimeIdeal(P): "Second argument should be a prime ideal";
return Lift([class],P,1);
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic Lift(class,P,m)->FldNumElt
{}

require IsPrimeIdeal(P): "Second argument should be a prime ideal";
require m gt 0: "the third argument must be positive";
ll:=LocalLift(class,P,m);
exp:=Valuation(Denominator(ll),P`IntegerGenerator);
exponents:=[Q`e*exp: Q in P`Parent`PrimeIdeals[P`IntegerGenerator]];
exponents[P`Position]:=m;
mult:=0;
Multiplier(~P,exponents,~mult);
return ll*mult;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic LocalCRT(~K,p,exponents,~Multipliers)
{}

nprimes:=#K`PrimeIdeals[p];
ntrees:=#K`TreesIntervals[p];
Pieces:=[K!0: i in [1..nprimes]];
MaxVTC:=[];
N:=0;
for tree in K`TreesIntervals[p] do
    ValuesToCompensate:=[0]; 
    for t in tree do
	if exponents[t] gt 0 then
	    extraden:=K`PrimeIdeals[p,t]`exponent;
	    expsTree:=[exponents[j]+extraden*K`PrimeIdeals[p,j]`e: j in tree];
	    MultPiece(~K`PrimeIdeals[p,t],tree,expsTree,~N,~Pieces[t]);
	    Append(~ValuesToCompensate,N+extraden);
	end if;
    end for;
    Append(~MaxVTC,Max(ValuesToCompensate));
end for;
if ntrees eq 1 then
    Betas:=[K!1];
else   
    Compensations:=[PolynomialRing(Integers())!0: i in [1..ntrees]];
    for i:=1 to ntrees do
	tree:=K`TreesIntervals[p,i];
	max:=Max([MaxVTC[k]: k in Exclude([1..ntrees],i)]);
	expsTree:=[exponents[j]+max*K`PrimeIdeals[p,j]`e: j in tree];
	CompensateValue(~K,p,tree,expsTree,~Compensations[i]);
    end for;
    universe:=&*Compensations;
//    Betas:=[Evaluate(universe div x,K.1): x in Compensations];
    Betas:=[K!Eltseq(universe div x): x in Compensations];
end if;
Multipliers:=[K!0: i in [1..nprimes]];
for i:=1 to ntrees do
    for t in K`TreesIntervals[p,i] do
	if exponents[t] gt 0 then
	    mult:=Pieces[t]*Betas[i];
	    MultiplyByInverse(~mult,~K`PrimeIdeals[p,t],exponents[t]);
// simplification
	    den:=Denominator(mult);
	    mx:=Max([Ceiling(exponents[k]/K`PrimeIdeals[p,k]`e): k in [1..nprimes]]);
	    module:=den*p^mx;
	    num:=PolynomialRing(Integers())!Eltseq(Numerator(mult),Integers()) mod module;
//	    mult:=Evaluate(num mod module,K.1)/den;    
	    Multipliers[t]:=K!Eltseq(num)/den;
	end if;
    end for;
end for;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic Localize(alpha,p)->RngIntElt,RngIntElt,RngUPolElt
{output=den,exp,Pol such that alpha = (1/den)*Pol(theta)*p^exp, and den is coprime to p}

if alpha eq 0 then 
    return 1,0,PolynomialRing(Integers())!0;
end if;
num:=Eltseq(Numerator(alpha),Integers());
valnum:=Min([Valuation(x,p): x in num]);
valden,den:=Valuation(Denominator(alpha),p);
return den,valnum-valden,PolynomialRing(Integers())!num div p^valnum;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic LocalLift(~type,p,class,~numlift,~denlift)
{class should belong to the residue class field  type[r]`Fq. 
The output is a pair g,e such that g(theta)/p^e is a lift to a P-integral element in K
and deg g(x)<n_P}

require class in type[#type]`Fq: "Second argument must lie in the residue field of first argument";
i:=1;
while class notin type[i]`Fq do
	i+:=1;
end while;
if i eq 1 then 
    numlift:=PolynomialRing(Integers())!Eltseq(type[1]`Fq!class,PrimeField(type[1]`Fq));
    denlift:=0;
else
    expden:=Ceiling(type[i]`V/type[i]`prode);
    V:=type[i]`prode*expden;
    log:=V*type[i]`logPi;
    log:=Vector(Remove(Eltseq(log),Degree(log)));
    newclass:=0;
    ConvertLogs(~type,log,~newclass);
    H:=V div type[i-1]`e;
    elt:=type[i]`z^(type[i-1]`invh*H)*class*newclass^(-1);
    varphi:=type[i-1]`FqY!Eltseq(type[i]`Fq!elt,type[i-1]`Fq);
    lift:=0;
    Construct(i-1,~type,p,varphi,[0,H],~lift);
    v1lift:=Min([Valuation(x,p): x in Coefficients(lift)]);
    numlift:=lift div p^v1lift;
    denlift:=expden-v1lift;
end if;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic LocalLift(class,P)->FldNumElt
{class should belong to the residue class field Z_K/P. 
The output is a lift to a P-integral element in K}

require IsPrimeIdeal(P): "Second argument should be a prime ideal";
numlift:=0;
denlift:=0;
LocalLift(~P`Type,P`IntegerGenerator,class,~numlift,~denlift);
// return  Evaluate(numlift,P`Parent.1)/P`IntegerGenerator^denlift;
return P`Parent!Eltseq(numlift)/P`IntegerGenerator^denlift;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic LocalLift(class,P,m)->FldNumElt
{}

require IsPrimeIdeal(P): "Second argument should be a prime ideal";
require m gt 0: "the third argument must be positive";
precision:=2*P`exponent+Ceiling(m/P`e);
SFL(~P,precision*P`e-P`Type[#P`Type]`V);
Zp:=pAdicRing(P`IntegerGenerator,precision);
Zpx:=PolynomialRing(Zp);
phi:=Zpx!P`Type[#P`Type]`Phi;
pi:=UniformizingElement(Zp);
LGnum:=Zpx!Eltseq(Numerator(P`LocalGenerator),Integers());
LGden:=Max([0,-P`LogLG[1]]);
lftnum:=Zpx!0;
lftden:=0;
num:=0;
den:=0;
//Horner's rule
for i:=m to 1 by -1 do
    LocalLift(~P`Type,P`IntegerGenerator,class[i],~num,~den);
    lftnum,lftden:=Cancel((lftnum*LGnum) mod phi,lftden+LGden:QUO:=false);
    lftnum,lftden:=Cancel(lftnum*pi^den+Zpx!num*pi^lftden,lftden+den:QUO:=false);
end for;
lftnum:=PolynomialRing(Integers())!lftnum;
if P`exponent ne 0 then
    lftnum:=lftnum mod Integers()!(pi^(lftden+Ceiling(m/P`e)));
end if;
// return Evaluate(lftnum,P`Parent.1)/Integers()!(pi^lftden);
return P`Parent!Eltseq(lftnum)/Integers()!(pi^lftden);
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic Montes(poly::RngUPolElt,p::RngIntElt: Numberfield:=false, Squarefree:=false) ->SeqEnum,SeqEnum, RngIntElt
{There is a triple output: OMreps= list of OM representations of the p-adic irreducible factors of poly;
TreesIntervals: list of intervals with the position of the first and last prime ideals in each disconnected tree of OM representations;
totalindex= p-index of the input polynomial.
The option Squarefree:=true enables the detection of a non-squarefree input poly.
The option Numberfield:=true forces the computation of the psi polynomial at the last level of each type.
}

require IsPrime(p): "First argument must be a prime integer";
require (CoefficientRing(poly) eq Integers() and IsMonic(poly)): "The polynomial must be monic and have integer coefficients";

TreesIntervals:=[];
position:=0;
totalindex:=0;   
OMreps:=[];
Pol:=poly;
mahler:=Infinity();
if Squarefree then
    n:=Degree(poly);
    NormPol:=&+[Abs(x): x in Coefficients(poly)];
    mahler:=Floor(n*Log(p,n)+(2*n-2)*Log(p,NormPol));
end if;
fa:=Factorization(PolynomialRing(GF(p))!Pol);
for factor in fa do
vprint montestalk,2: "Analyzing irreducible factor modulo p: ",factor[1];
    Leaves:=[InitialPrimeIdeal(Pol,p,factor[1],factor[2])];
    Montesloop(~Pol,~Leaves,~totalindex,mahler: NF:=Numberfield);
    if Squarefree and totalindex gt mahler then 
	print "The input polynomial is not separable";
	return [], [], Infinity();
    end if;
    Append(~TreesIntervals,[position+1..position+#Leaves]);
    position+:=#Leaves;
    OMreps cat:=Leaves;  
end for;
return OMreps,TreesIntervals,totalindex;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////

intrinsic Montesloop(~Pol,~Leaves,~totalindex,mahler: NF:=false)
{Main loop of the Montes algorithm. 
The iteration stops as soon as totalindex is greater than the given mahler bound.}

p:=Leaves[1]`IntegerGenerator;	
Stack:=Leaves;
Leaves:=[];
while #Stack gt 0 and totalindex le mahler do	  
    omrep:=Stack[#Stack];
    Prune(~Stack);
    r:=#omrep`Type;
vprint montestalk,2:  "Analyzing type of order ",r;
vprint montestalk,2:  "Phir=",omrep`Type[r]`Phi;
    sides:=[];
    devsEachSide:=[* *];
    phiadic:=Taylor(Pol,omrep`Type[r]`Phi,omrep`Type[r]`omega);
    Newton(r,~omrep`Type,~phiadic,p,~sides,~devsEachSide);
vprint montestalk,3: "Sides of Newton polygon:",sides;
    lengthN:=omrep`Type[r]`omega;
    indexN:=-omrep`Type[r]`cuttingslope*(lengthN*(lengthN-1) div 2); 
    firstabscissa:= sides[1,2];
    if firstabscissa gt 1 then
	print "The input polynomial is not separable";
	totalindex:=Infinity(); 
	return;
    end if;
    if lengthN eq 1 or firstabscissa eq 1 then
vprint montestalk,2:  "Found a factor of depth  ",r-1;
	if firstabscissa eq 1 then 
	    Pol:=Pol div omrep`Type[r]`Phi;
	    omrep`Type[r]`slope:=Infinity();
	    if lengthN eq 1 then
		sides:=[];
	    else
		indexN+:=Integers()!sides[1,3]-sides[#sides,5];
	    end if;
	else
	    LastLevel(phiadic,~omrep,-sides[1,1],devsEachSide[1]: Lastpsi:=NF);
	    sides:=[];
	end if;
	Append(~Leaves,omrep);
    end if;
    prevh:=0;	
    for i:=#sides to 1 by -1 do  // GRAN FOR  COSTATS
	side:=sides[i];
vprint montestalk,2:  "Analyzing side ",side;        
	h:=-Numerator(side[1]);
	e:=Denominator(side[1]);
	omrep`Type[r]`h:=h;
	omrep`Type[r]`e:=e;
	omrep`Type[r]`slope:=-side[1];
	omrep`Type[r]`invh:=InverseMod(h,e);
	lprime:=(1-omrep`Type[r]`invh*h) div e;
	newPi:=Eltseq(omrep`Type[r]`invh*omrep`Type[r]`logPhi+lprime*omrep`Type[r]`logPi);
	Append(~newPi,0);  
	omrep`Type[r]`logGamma:=e*omrep`Type[r]`logPhi-h*omrep`Type[r]`logPi;
   	Ei:=Integers()!(side[4]-side[2]);
	Hi:=Integers()!(side[3]-side[5]);
	indexN+:=Ei*prevh+((Ei*Hi-Ei-Hi+(Ei div e))div 2);
	prevh+:=Hi;
	respol:=0;
	ResidualPolynomial(r,~omrep`Type,p,~devsEachSide[i],~respol);
        respol:=respol/LeadingCoefficient(respol);
	factors:=Factorization(respol);
vprint montestalk,2: "Monic Residual Polynomial=",respol;
vprint montestalk,3:  "Factors of R.P.:=",factors;         
        for factor in factors do     
vprint montestalk,2: "Analyzing factor of the Res.Pol.",factor[1];  
            newom:=omrep;  
            newom`Type[r]`psi:=factor[1];
	    newom`Type[r]`f:=Degree(newom`Type[r]`psi);
	    Representative(~newom`Type,p);
// IF REFINA-AVANCA
	    if Degree(newom`Type[r]`Phi) eq Degree(newom`Type[r+1]`Phi) then
vprint montestalk,2:  "Refining. Cuttingslope=",-side[1];
		if #sides gt 1 or #factors gt 1 then
		    Append(~newom`Type[r]`Refinements,[*newom`Type[r]`Phi,newom`Type[r]`slope *]);
		end if;
		newom`Type[r]`cuttingslope:=-side[1];
		newom`Type[r]`Phi:=newom`Type[r+1]`Phi;
		newom`Type[r]`omega:=factor[2];
		Prune(~newom`Type);  
	    else
vprint montestalk,2:  "Proceeding to higher order";    
		newom`Type[r+1]`omega:=factor[2];
		newom`Type[r+1]`logPi:=Vector(newPi);
		vect:=-newom`Type[r+1]`V*newom`Type[r+1]`logPi;
		vect[r+2]:=1;
		newom`Type[r+1]`logPhi:=vect; 
            end if; 
// FINAL IF REFINA-AVANCA
	    Append(~Stack,newom);
        end for;     
    end for; // FINAL GRAN FOR COSTATS
    totalindex+:=omrep`Type[r]`prodf*indexN;
vprint montestalk, 2: "Added  ",omrep`Type[r]`prodf*indexN," to the index";
end while;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Montes(K::FldNum,p::RngIntElt)
{Apply the Montes algorithm to the number field K and the rational prime p. 
}
require IsPrime(p): "First argument must be a prime integer";
Pol:=DefiningPolynomial(K);
require (CoefficientRing(Pol) eq Integers() and IsMonic(Pol)): "Number Field must be defined by a monic integral polynomial";

if not assigned K`FactorizedPrimes then
    K`FactorizedPrimes:=[];
    K`PrimeIdeals:=AssociativeArray();
    K`LocalIndex:=AssociativeArray();
    K`TreesIntervals:=AssociativeArray();
end if;    
if p in K`FactorizedPrimes then
    return;
end if;
K`PrimeIdeals[p],TreesIntervals,totalindex:=Montes(Pol,p: Numberfield:=true);
Psi:=0;
logLG:=0;
pos:=1;
for i in [1..#K`PrimeIdeals[p]] do
    K`PrimeIdeals[p,i]`Parent:=K;
    K`PrimeIdeals[p,i]`IsPrime:=true;
    K`PrimeIdeals[p,i]`IsIntegral:=true;
    K`PrimeIdeals[p,i]`Position:=pos;
    K`PrimeIdeals[p,i]`Factorization:=[[p,pos,1]];
    pos+:=1;
    K`PrimeIdeals[p,i]`FactorizationString:=FactorListToString(K`PrimeIdeals[p,i]`Factorization);
    K`PrimeIdeals[p,i]`e:=K`PrimeIdeals[p,i]`Type[#K`PrimeIdeals[p,i]`Type]`prode;
    K`PrimeIdeals[p,i]`f:=K`PrimeIdeals[p,i]`Type[#K`PrimeIdeals[p,i]`Type]`prodf; 
    PrescribedValue(~K`PrimeIdeals[p,i]`Type,1,~Psi,~logLG);
    K`PrimeIdeals[p,i]`LocalGenerator:=
                K![ Coefficient(Psi, j) : j in [0..Degree(K)-1] ] * p^logLG[1];
    K`PrimeIdeals[p,i]`LogLG:=logLG;
end for;
if #K`PrimeIdeals[p] eq 1 then
    K`PrimeIdeals[p,1]`Type[#K`PrimeIdeals[p,1]`Type]`Phi:=Pol;
    K`PrimeIdeals[p,1]`Type[#K`PrimeIdeals[p,1]`Type]`slope:=Infinity();
end if;
Append(~K`FactorizedPrimes,p);
Sort(~K`FactorizedPrimes);
K`LocalIndex[p]:=totalindex;
K`TreesIntervals[p]:=TreesIntervals;
CrossValues(~K,p);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////


intrinsic Multiplier(~P,exponents,~mult)
{Compute an element  mult in the number field Parent(P) which is congruent to 1 modulo P^a_P and it has Q-value >= a_Q.
The output has a power of p as denominator; thus, if all a_Q>=0, the output is an algebraic integer}

p:=P`IntegerGenerator;
// part of the tree of P
treeP:=0;
TreeInterval(~P,~treeP);
N:=0;
bp:=0;
expsTree:=[exponents[i]+P`exponent*P`Parent`PrimeIdeals[p,i]`e:i in treeP];
MultPiece(~P,treeP,expsTree,~N,~bp);

// part of the rest of the trees
betatree:=0;
beta:=PolynomialRing(Integers())!1;
for tree in Exclude(P`Parent`TreesIntervals[p],treeP) do
    exps:=[exponents[t]+(N+P`exponent)*P`Parent`PrimeIdeals[p,t]`e: t in tree];
    CompensateValue(~P`Parent,p,tree,exps,~betatree);
    beta*:=betatree;
end for;
// mult:=bp*Evaluate(beta,P`Parent.1);
mult:=bp*P`Parent!Eltseq(beta);
MultiplyByInverse(~mult,~P,exponents[P`Position]);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic MultipliersGenerators(~K,p,~Multipliers)
{}

nprimes:=#K`PrimeIdeals[p];
ntrees:=#K`TreesIntervals[p];
Pieces:=[K!0: i in [1..nprimes]];
MaxVTC:=[];
N:=0;
mx:=Max([2/K`PrimeIdeals[p,k]`e: k in [1..nprimes]]);
for tree in K`TreesIntervals[p] do
    ValuesToCompensate:=[0]; 
    for t in tree do
	extraden:=Max([0,-K`PrimeIdeals[p,t]`LogLG[1]]);
	expsTree:=[Max([2,1+extraden*K`PrimeIdeals[p,j]`e]): j in tree];
	MultPiece(~K`PrimeIdeals[p,t],tree,expsTree,~N,~Pieces[t]);
	Append(~ValuesToCompensate,N+extraden);
    end for;
    Append(~MaxVTC,Max(ValuesToCompensate));
end for;
if ntrees eq 1 then
    Betas:=[K!1];
else   
    Compensations:=[PolynomialRing(Integers())!0: i in [1..ntrees]];
    for i:=1 to ntrees do
	tree:=K`TreesIntervals[p,i];
	max:=Max([MaxVTC[k]: k in Exclude([1..ntrees],i)]);
	expsTree:=[2+max*K`PrimeIdeals[p,j]`e: j in tree];
	CompensateValue(~K,p,tree,expsTree,~Compensations[i]);
    end for;
    universe:=&*Compensations;
//    Betas:=[Evaluate(universe div x,K.1): x in Compensations];
    Betas:=[K!Eltseq(universe div x): x in Compensations];
end if;
Multipliers:=[K!0: i in [1..nprimes]];
for i:=1 to ntrees do
    for t in K`TreesIntervals[p,i] do
	mult:=Pieces[t]*Betas[i];
// simplification
	extraden:=Max([0,-K`PrimeIdeals[p,t]`LogLG[1]]);
	den:=Denominator(mult);
	module:=den*p^(extraden+Ceiling(mx));
	num:=PolynomialRing(Integers())!Eltseq(Numerator(mult),Integers());
//	mult:=Evaluate(num mod module,K.1)/den;    
	mult:=K!Eltseq(num mod module)/den;    
	Multipliers[t]:=mult;
    end for;
end for;
end intrinsic;

///////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////

intrinsic MultiplyByInverse(~alpha,~P,m)
{Divide alpha by a  pseudo-inverse, so that after the routine, it is congruent to 1 modulo P^m}

//Zx:=PolynomialRing(Integers());
require m gt 0: "the third argument must be positive";
value,redalpha:=PValuation(alpha,P: RED:=true);
//print alpha,redalpha;
//print Quotrem(Zx!Eltseq(alpha,Integers()),P`Type[1]`Phi);
require value eq 0: "the first argument is not invertible modulo the second argument";
p:=P`IntegerGenerator;
xnum:=0;
xden:=0;
LocalLift(~P`Type,P`IntegerGenerator,redalpha^(-1),~xnum,~xden);
//print "local lift",PValuation(1-alpha*Evaluate(xnum,P`Parent.1)/p^xden,P);
alphaden:=Valuation(Denominator(alpha),p);
precision:=Max([alphaden,2*P`exponent])+Ceiling(m/P`e);
SFL(~P,precision*P`e-P`Type[#P`Type]`V);
Zp:=pAdicRing(p,precision);
Zpx:=PolynomialRing(Zp);
phi:=Zpx!P`Type[#P`Type]`Phi;
alphanum:=Zpx!Eltseq(Numerator(alpha),Integers()) mod phi;
alphanum,alphaden:=Cancel(alphanum,alphaden:QUO:=false);
h:=1;
while h lt m do
    h*:=2;
    lowprecision:=2*P`exponent+Ceiling(h/P`e);
    Inversionloop([*alphanum,alphaden*],~xnum,~xden,phi,lowprecision,Zp);
//print "loop",PValuation(1-alpha*Evaluate(Zx!xnum,P`Parent.1)/p^xden,P);
end while;  
//alpha*:=Evaluate(PolynomialRing(Integers())!xnum,P`Parent.1)/p^xden;
alpha*:=P`Parent!xnum/p^xden;
end intrinsic;

//////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic MultPiece(~P,tree,expsTree,~N,~bp)
{Compute  bp in Parent(P) which has P-value zero and 
v_Q(bp) >= expsTree[Q]+extraden*e_Q, for all Q\ne P in the tree.}

bp:=P`Parent!1;
N:=0;
if #tree eq 1 then    
    return;
end if;
p:=P`IntegerGenerator;
j:=P`Position-tree[1]+1;
N:=&+[Numerator(P`Parent`PrimeIdeals[p,k]`CrossValues[j]): k in tree];
ExcludeP:=Exclude(tree,P`Position);
for t in ExcludeP do
    k:=t-tree[1]+1;
    outPt:=Exclude(ExcludeP,t);
    if #outPt eq 0 then
	wPkAllPhis:=0;
    else
	wPkAllPhis:=&+[Denominator(P`Parent`PrimeIdeals[p,l]`CrossValues[j])*P`Parent`PrimeIdeals[p,l]`CrossValues[k]: l in outPt];
    end if;
    e:=P`Parent`PrimeIdeals[p,t]`e;
    ord:=#P`Parent`PrimeIdeals[p,t]`Type;
    V:=P`Parent`PrimeIdeals[p,t]`Type[ord]`V;
    CVPk:=P`Parent`PrimeIdeals[p,t]`CrossValues;
    den:=Denominator(CVPk[j]);
    wPk:=((expsTree[k]/e)+N-wPkAllPhis)/den;
    SFL(~P`Parent`PrimeIdeals[p,t],Ceiling(wPk*e)-V);
    M:=Max([1+Floor(Max(CVPk)),Ceiling(wPk)]);
    phi:=P`Parent`PrimeIdeals[p,t]`Type[ord]`Phi mod p^M;
//    bp*:=Evaluate(phi^den,P`Parent.1);
    bp*:=P`Parent!Eltseq(phi^den);
end for;
bp*:=p^(-N);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Newton(i,~type,~phiadic,p,~sides,~devsEachSide)
{Given a type of order at least i, and the phiadic expansion of a polynomial, compute:
  - sides=list of sides of the r-th order Newton polygon w.r.t. the type;
  - devsEachSide[k]=list of multiadic phi_1,...,phi_i-1 expansion of the coefficients of 
  the polynomial whose attached point lies on sides[k].}

require i le #type: "the first input is too large";
n:=0;
cloud:=[];
devsEachSide:=[* *];
alldevs:=[* *];
if i eq 1 then 
    zero:=0;
else
    zero:=[];
end if;
val:=0;
dev:=[* *];
for k in [1..#phiadic] do 
        Value(i,~type,~phiadic[k],p,~dev,~val);
        if IsFinite(val) then 
	    Append(~cloud,<k-1,val+n>);  
	    Append(~alldevs,dev);
        end if;
        n+:=type[i]`V;
end for;
V:=NewtonPolygon(cloud);
s:=LowerVertices(V);
sides:=[[LowerSlopes(V)[k],s[k,1],s[k,2],s[k+1,1],s[k+1,2]]: k in [1..#LowerSlopes(V)]];
abscissas:=[x[1] : x in cloud];
for sd in sides do
    height:=Integers()!sd[3];
    dev:=[* *];
    for jj:=Integers()!sd[2] to Integers()!sd[4] by Denominator(sd[1]) do 
	position:=Index(abscissas,jj);
	if position gt 0 and cloud[position,2] eq height then
	    Append(~dev,alldevs[position]);
	else
	    Append(~dev,zero);
	end if;
	height:=height+Numerator(sd[1]);  
    end for;
    Append(~dev,[Integers()!sd[2],Integers()!sd[3]]);
    Append(~devsEachSide,dev);
end for;
if #sides eq 0 then
      sides:=[[0,s[1,1],s[1,2],s[1,1],s[1,2]]];
      devsEachSide:=[* alldevs[Index(abscissas,Integers()!s[1,1])],[Integers()!s[1,1],Integers()!s[1,2]] *];
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

intrinsic PathOfPrecisions(n,h) -> SeqEnum
{}

q:=n;
precs:=[n];
while q gt h do
    q,a:=Quotrem(q,2);
    q+:=a;
    Append(~precs,q);
end while;
return Reverse(precs);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

intrinsic pDiscriminant(polynomial::RngUPolElt,p::RngIntElt)-> RngIntElt,RngIntElt 
{Compute:
 -pdiscK: sum of the p-adic valuations of the discriminants of all local 
  extensions of Q_p, given by the irreducible p-adic factors of the given polynomial.
-pdiscf: is the p-adic valuation of the discriminant of polynomial.
Note that the discriminant itself is not computed.
}

require IsPrime(p): "First argument must be a prime integer";
require (CoefficientRing(polynomial) eq Integers() and IsMonic(polynomial)): "The polynomial must be monic and integral";

pls,OMReps,totalindex:=pAdicFactors(p,polynomial,0);
if totalindex eq Infinity() then 
    return Infinity(),Infinity(); 
end if;
disc:=0;
difft:=0;
for i:=1 to #OMReps do
    Different(~OMReps[i],p,~difft);
    disc+:=OMReps[i][#OMReps[i]]`prodf*difft;
end for;
return disc, disc+2*totalindex;
end intrinsic;

///////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic pAdicFactors(polynomial::RngUPolElt,p::RngIntElt,prec::RngIntElt: SQF:=false)->SeqEnum
{Computes a list of Okutsu approximations to the irreducible p-adic factors of the given polynomial, all of them correct modulo p^precision.
If SQF:=true the routine checks that the input polynomial is squarefree
}
require IsPrime(p): "First argument must be a prime integer";
require (CoefficientRing(polynomial) eq Integers() and IsMonic(polynomial)): "The polynomial must be monic and integral";

OMreps,_,_:=Montes(polynomial,p: Squarefree:=SQF);
if #OMreps eq 1 then
    return[polynomial];
end if;
for i:=1 to #OMreps do
    ord:=#OMreps[i]`Type;
    slope:=OMreps[i]`Type[ord]`prode*(prec+OMreps[i]`exponent+1)-OMreps[i]`Type[ord]`V;
    SFL(~OMreps[i],slope,polynomial);
end for;
return [T`Type[#T`Type]`Phi: T in OMreps];
end intrinsic;

///////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic pHermiteBasis(K::FldNum,p::RngIntElt)->SeqEnum
{Compute a  p-integral basis of ZK in HNF}

Montes(K,p: Basis:=true);
if not IsDefined(K`pHermiteBasis,p) then
    n:=Degree(K);
    Nums:=[Reverse(Eltseq(Numerator(x),Integers())): x in K`pBasis[p]];
    Dens:=[Valuation(Denominator(x),p): x in K`pBasis[p]];
    maxexp:=Max(Dens);
    Zp:=pAdicRing(p,maxexp+1);
    pi:=UniformizingElement(Zp);
    Nums:=Matrix(Reverse([[Zp!Nums[i,j]*pi^(maxexp-Dens[i]): j in [1..n]]: i in [1..n]]));

    H:=HermiteForm(Nums);

    pmax:=p^maxexp;
    Dens:=[pmax div Integers()!H[i,i]: i in [1..n]];
    H:=[[H[i,j] div H[i,i]: j in [1..n]]: i in [1..n]];
    K`pHermiteBasis[p]:=Reverse([K!Reverse(H[k])/Dens[k] : k in [1..n]]);
end if;
return K`pHermiteBasis[p];
end intrinsic;   
/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic PrescribedValue(~type,value,~Phi,~logphi)
{Compute a polynomial Phi=phi_1^a_1...phi_r^a_r such that v_P(p^a_0Psi(theta))=value, 
where P is the prime determined by the given type with Okutsu depth r. 
The exponents a_0,...,a_r are stored in the list logphi.}

Phi:=PolynomialRing(Integers())!1;
logphi:=RSpace(Integers(),#type)!0;
qq,val:=Quotrem(value,type[#type]`prode);
logphi[1]:=qq;
if val gt 0 then
    body:=val;
    for k:=#type-1 to 1 by -1 do
	jj:=type[k]`invh*body mod type[k]`e;
	logphi[k+1]:=jj;
	Phi*:=type[k]`Phi^jj;
	res:=(body-jj*type[k]`h) div type[k]`e;
	body:=res-jj*type[k]`V;
    end for;
    logphi[1]+:=res;
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic pResultant(p::RngIntElt,polynomial::RngUPolElt,polynomial2::RngUPolElt)-> RngIntElt
{Compute the p-adic valuation of the resultant of the two given univariate polynomials.
}

require IsPrime(p): "First argument must be a prime integer";
require (CoefficientRing(polynomial) eq Integers() and IsMonic(polynomial)): "The first polynomial must be monic and integral";
require (CoefficientRing(polynomial2) eq Integers() and IsMonic(polynomial2)): "The second polynomial must be monic and integral";

Pol:=polynomial;
Pol2:=polynomial2;
if Degree(Pol) gt Degree(Pol2) then
    Pol:=polynomial2;
    Pol2:=polynomial;
end if;
Norm:=&+[Abs(x)^2: x in Coefficients(Pol)];
Norm2:=&+[Abs(x)^2: x in Coefficients(Pol2)];
mahler:=Floor((Degree(Pol2)*Log(p,Norm)+Degree(Pol)*Log(p,Norm2))/2);
fa:=Factorization(PolynomialRing(GF(p))!Pol);
totalres:=0;
for factor in fa do
    b:=VValuation(PolynomialRing(GF(p))!Pol2,factor[1]);
    if b eq 0 then 
	continue; 
    end if;
    omrep:=InitialPrimeIdeal(p,Pol,factor[1],factor[2]);
    omrep`f:=b;
    Stack:=[omrep];
    while #Stack gt 0 and totalres le mahler do
	omrep:=Stack[#Stack];
	Prune(~Stack);
	r:=#omrep`Type;
	Phiadic:=Taylor(Pol,omrep`Type[r]`Phi,omrep`Type[r]`omega);
	Phiadic2:=Taylor(Pol2,omrep`Type[r]`Phi,omrep`f);
	sides:=[]; 
	sides2:=[];
	devsSides:=[* *]; 
	devsSides2:=[* *];	  
	Newton(r,~omrep`Type,~Phiadic,p,~sides,~devsSides);
	Newton(r,~omrep`Type,~Phiadic2,p,~sides2,~devsSides2);
	partialres:=-omrep`Type[r]`cuttingslope*omrep`Type[r]`omega*omrep`f; 
	if sides[1,2] gt 0 then
	    if sides2[1,2] gt 0 then 
		return Infinity(); 
	    end if;
	    partialres+:=sides[1,2]*(sides2[1,3]-sides2[#sides2,5]);
	    Pol:=Pol div omrep`Type[r]`Phi^Integers()!sides[1,2];
	end if;
	if sides2[1,2] gt 0 then
	    Pol2:=Pol2 div omrep`Type[r]`Phi^Integers()!sides2[1,2];
	    partialres+:=sides2[1,2]*(sides[1,3]-sides[#sides,5]);
	end if;
	if sides[1,1] eq 0 or sides2[1,1] eq 0 then 
	    sides:=[];
	end if;
	for s:=1 to #sides do 
	    side:=sides[s];
	    lambda:=side[1];
	    omrep`Type[r]`h:=-Numerator(lambda);
	    omrep`Type[r]`e:=Denominator(lambda);
	    omrep`Type[r]`slope:=-lambda;
	    omrep`Type[r]`invh:=InverseMod(omrep`Type[r]`h,omrep`Type[r]`e);
	    lprime:=(1-omrep`Type[r]`invh*omrep`Type[r]`h) div omrep`Type[r]`e;
	    newPi:=ElementToSequence(omrep`Type[r]`invh*omrep`Type[r]`logPhi+lprime*omrep`Type[r]`logPi);
	    Append(~newPi,0);
	    omrep`Type[r]`logGamma:=omrep`Type[r]`e*omrep`Type[r]`logPhi-omrep`Type[r]`h*omrep`Type[r]`logPi;
	    acumE:=0;
	    acumH:=0;
	    for side2 in sides2 do
		if lambda gt side2[1] then 
		    acumE+:=Integers()!(side2[4]-side2[2]);
		else
		    acumH+:=Integers()!(side2[3]-side2[5]);
		end if;
	    end for;
	    partialres+:=(side[3]-side[5])*acumE+(side[4]-side[2])*acumH;
	    lloc:=Index([x[1]: x in sides2],lambda);
	    if  lloc eq 0 then 
		continue; 
	    end if;
	    psi:=0;
	    ResidualPolynomial(r,~omrep`Type,p,~devsSides[s],~psi);
	    respol:=psi/LeadingCoefficient(psi);
	    ResidualPolynomial(r,~omrep`Type,p,~devsSides2[lloc],~psi);
	    respol2:=psi/LeadingCoefficient(psi);
	    factors:=Factorization(respol);
	    for factor in factors do        
		newomrep:=omrep;
		newomrep`f:=VValuation(respol2,factor[1]);
		if newomrep`f eq 0 then 
		    continue; 
		end if;
		newomrep`Type[r]`psi:=factor[1];
		newomrep`Type[r]`f:=Degree(factor[1]);
		if newomrep`Type[r]`omega eq 1 then
		    newomrep`Phiadic[1]:=Phiadic[1];
		    newomrep`Phiadic[2]:=Phiadic[2];
		    SFL(~newomrep,2*newomrep`Type[r]`h,Pol);     
		    newomrep`Type[r]`cuttingslope:=newomrep`Type[r]`h;
		else
		    Representative(~newomrep`Type,p);
		    r1:=r+1;
		    if factor[2] eq 1 then 
			nur:=&+[newomrep`Type[j]`slope/newomrep`Type[j]`prode: j in [1..r]]; 
			newomrep`exponent:=Floor((newomrep`Type[r1]`V/newomrep`Type[r1]`prode)-nur);
		    end if;
		    if Degree(newomrep`Type[r]`Phi) eq Degree(newomrep`Type[r1]`Phi) then 
			newomrep`Type[r]`Phi:=newomrep`Type[r1]`Phi;
			newomrep`Type[r]`omega:=factor[2];
			newomrep`Type[r]`cuttingslope:=newomrep`Type[r]`h;
			Prune(~newomrep`Type);
		    else
			newomrep`Type[r1]`omega:=factor[2];
			newomrep`Type[r1]`logPi:=Vector(newPi);         
			vect:=-newomrep`Type[r+1]`V*newomrep`Type[r+1]`logPi;
			vect[r+2]:=1;
			newomrep`Type[r+1]`logPhi:=vect; 
		    end if; 
		end if;
		Append(~Stack,newomrep);
	    end for;     
	end for; 
	totalres+:=newomrep`Type[r]`prodf*Integers()!partialres;
    end while; 
    if totalres gt mahler then 
	return Infinity(); 
    end if;
end for;
return totalres;
end intrinsic;

////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////

intrinsic PValuation(alpha::FldRatElt, P::Rec: RED:=false)->RngIntElt,FldFinElt
{Compute the P-valuation v of alpha at the prime ideal P.
If the option RED is set to true, compute also the class of alpha in P^v/P^(v+1).
}
return PValuation(P`Parent!alpha,P);
end intrinsic;

intrinsic PValuation(alpha::RngIntElt, P::Rec: RED:=false)->RngIntElt,FldFinElt
{Compute the P-valuation v of alpha at the prime ideal P.
If the option RED is set to true, compute also the class of alpha in P^v/P^(v+1).
}
return PValuation(P`Parent!alpha,P);
end intrinsic;

intrinsic PValuation(alpha::FldNumElt,P::Rec: RED:=false)->RngIntElt,FldFinElt
{Compute the P-valuation v of alpha at the prime ideal P.
If the option RED is set to true, compute also the class of alpha in P^v/P^(v+1).
}
require IsPrimeIdeal(P): "Second argument should be a prime ideal";
require alpha in P`Parent: "Arguments should lie on the same number field";

Fp:=PrimeField(P`Type[1]`Fq);
reduction:=Fp!0;
if alpha eq 0 then 
    return Infinity(),reduction; 
end if;
den,exp,numPol:=Localize(alpha,P`IntegerGenerator);
cua:=exp*P`e;
if VValuation(PolynomialRing(Fp)!numPol,PolynomialRing(Fp)!P`Type[1]`Phi) eq 0 then 
    if RED then
	ConvertLogs(~P`Type,-cua*P`LogLG,~reduction);
	reduction*:=(Fp!den)^(-1)*Evaluate(numPol,P`Type[1]`z);
    end if;
    return cua,reduction; 
end if;
respol:=0;
z:=0;
dev:=[* *];
val:=0;
value:=0;
i:=0;
while value eq 0 do
    if i lt #P`Type then
	i+:=1;
    else
	SFL(~P,2*P`Type[#P`Type]`h: update:=true);
    end if;
    Value(i+1,~P`Type,~numPol,P`IntegerGenerator,~dev,~val);
    ResidualPolynomial(i,~P`Type,P`IntegerGenerator,~dev,~respol);
    if VValuation(respol,P`Type[i]`psi) eq 0 then
	value:=val*(P`e div (P`Type[i]`e*P`Type[i]`prode));
    end if;
end while;
if RED then
    log:=dev[#dev,1]*P`Type[i]`logPhi+dev[#dev,2]*P`Type[i]`logPi;
    EqualizeLogs(~P`LogLG,~log);
    ConvertLogs(~P`Type,log-(value+cua)*P`LogLG,~reduction);
    Z(~P`Type,i,~z);
    reduction*:=(Fp!den)^(-1)*Evaluate(respol,z);
end if;
return value+cua,reduction;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic 'mod'(alpha:: FldNumElt, P:: Rec)->FldFinElt
{Compute the reduction map ZK--> ZK/P}
// It's a copy of Reduction, with better name
return Reduction(alpha,P);
end intrinsic;

intrinsic Reduction(alpha:: FldNumElt, P:: Rec)->FldFinElt
{Compute the reduction map ZK--> ZK/P}

return Reduction(alpha,P,1)[1];
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Reduction(alpha:: FldNumElt, P:: Rec, m::RngIntElt)->SeqEnum
{Compute the reduction map ZK--> ZK/P^m}

require IsPrimeIdeal(P): "The second argument should be a prime ideal";
require m gt 0: "The third argument should be positive";
beta:=alpha;
Shrink(~beta,~P,m);
value,red:=PValuation(beta,P: RED:=true);
require value ge 0: "First argument should be P-integral";
class:=[P`Type[#P`Type]`Fq!0: i in [1..m]];
while value lt m do
    class[value+1]:=red;
    if value eq m-1 then
	value:=m;
    else
	beta-:=LocalLift(red,P)*P`LocalGenerator^value;
	Shrink(~beta,~P,m);
	value,red:=PValuation(beta,P: RED:=true);
    end if;
end while;
return class;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Representative(~type,p)
{Construction of a representative phi of a type. 
We add phi and V at a new level of type}

s:=#type;
ef:=type[s]`e*type[s]`f;
u:=ef*type[s]`V+type[s]`f*type[s]`h;                          
newphi:=0;
Construct(s,~type,p,Reductum(type[s]`psi),[0,u],~newphi);                   
newphi+:=type[s]`Phi^ef;          
newlevel:=rec<TypeLevel| 
Phi:=newphi, 
V:=type[s]`e*u, 
cuttingslope:=0, 
Refinements:=[* *],
prode:=type[s]`prode*type[s]`e,
prodf:=type[s]`prodf*type[s]`f,
Fq:=ext<type[s]`Fq| type[s]`psi>
>;
newlevel`FqY:=PolynomialRing(newlevel`Fq);
AssignNames(~(newlevel`Fq),["z" cat IntegerToString(s)]);
AssignNames(~(newlevel`FqY),["Y" cat IntegerToString(s)]);
if type[s]`f gt 1 then
    mmm,nnn:=HasAttribute(newlevel`Fq,"PowerPrinting");
    if mmm and nnn then
	AssertAttribute(newlevel`Fq,"PowerPrinting",false); 
    end if;
    newlevel`z:=newlevel`Fq.1;
else
    newlevel`z:=-Coefficient(type[s]`psi,0);                                              
end if;             
Append(~type,newlevel);
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic ResidualPolynomial(i,~type,p,~devsSide,~psi)
{Internal procedure to compute the i-th residual polynomial psi with respect to
a side S  of slope -type[i]`slope of the Newton polygon of a certain polynomial Pol. 
The coefficients of Pol whose attached  points in N_i(Pol) lie on S have multiadic expansions 
contained in the list devsSide.
}
	
require i le #type: "the first input is too large";
pj:=0;
rescoeffs:=[type[i]`Fq!0 : j in [1..#devsSide-1]];
if i eq 1 then
    height:=devsSide[#devsSide,2];
    for j:=1 to #devsSide-1 do
	dev:=devsSide[j];
	if not dev eq 0 then
	    rescoeffs[j]:=Evaluate(dev div p^height,type[i]`z);
	end if;
    height:=height-type[i]`h;
    end for;
else
    lprime:=(1-type[i-1]`invh*type[i-1]`h) div type[i-1]`e;
    for j:=1 to #devsSide-1 do
	dev:=devsSide[j];
	if not #dev eq 0 then
	    txp:=lprime*dev[#dev,1]-type[i-1]`invh*dev[#dev,2];
	    ResidualPolynomial(i-1,~type,p,~dev,~pj);
	    rescoeffs[j]:=type[i]`z^txp*Evaluate(pj,type[i]`z);
	end if;
    end for;
end if;
psi:=type[i]`FqY!rescoeffs;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////

intrinsic SFL(~P::Rec,slope::RngIntElt,Pol: UPD:=false)
{in P`sfl and P`Phiadic we stored relevant data. The aim is P`Type[#P`Type]`slope>=slope}

p:=P`IntegerGenerator;
ord:=#P`Type;
if P`Type[ord]`slope ge slope then
    return;
end if;
if P`sfl[3] eq 0 then
    SFLInitialize(~P,Pol);
end if;
nu:=P`sfl[2];
x0prec:=P`sfl[3];
x0num:=P`Phiadic[4];
x0den:=P`sfl[4];
e:=P`Type[ord]`prode;
h:=P`Type[ord]`h-P`Type[ord]`cuttingslope;
lasth:=slope-P`Type[ord]`cuttingslope;
V:=P`Type[ord]`V+P`Type[ord]`cuttingslope;

Zp:=pAdicRing(p);
piZp:=UniformizingElement(Zp);
Zp`DefaultPrecision:=nu+P`exponent+Ceiling((V+lasth)/e);
PolZp:=AdaptPrecision(Zp,P`Phiadic[5],P`Phiadic[6]);	
PsinumZp:=AdaptPrecision(Zp,P`Phiadic[3],P`Phiadic[7]);
path:=PathOfPrecisions(lasth,h);
shortpath:=PathOfPrecisions(h,x0prec);
Zp`DefaultPrecision:=nu+P`exponent+Ceiling(h/e);
a1:=PolynomialRing(Zp)!P`Phiadic[2];
zq:=quo<Zp|piZp^(nu+P`exponent+Ceiling((V+path[2])/e))>;
zqt<t>:=PolynomialRing(zq);
phi:=zqt!P`Type[ord]`Phi;
Psinum:= zqt!PsinumZp;
A0num, A0den := Cancel((zqt!P`Phiadic[1]*Psinum) mod phi,nu);
A1num, A1den := Cancel((zqt!a1*Psinum) mod phi,nu);
for i in [2..#shortpath] do
    lowprecision:=A1den+2*x0den+Ceiling(shortpath[i]/e);
    Inversionloop([* A1num,A1den *],~x0num,~x0den,phi,lowprecision,Zp);
end for;  
Anum, Aden := Cancel((A0num*zqt!x0num) mod phi, x0den);
phi:=phi+Anum;
//print "primera h", testh(P`Type,phi,p,Pol);

for i in [2..#path-1] do
    zq:=quo<Zp|piZp^(nu+P`exponent+Ceiling((V+path[i+1])/e))>;
    zqt<t>:=PolynomialRing(zq);
    phi:=zqt!phi;
    Psinum:= zqt!PsinumZp;
    qq,c0:=Quotrem(zqt!PolZp,phi);
    c1:=qq mod phi;
    C0num,C0den := Cancel((c0*Psinum) mod phi,nu);
    C1num,C1den := Cancel((c1*Psinum) mod phi,nu);
    lowprecision:=C1den+2*x0den+Ceiling(path[i]/e);
    Inversionloop([* C1num,C1den *],~x0num,~x0den,phi,lowprecision,Zp);
    Cnum,Cden:=Cancel((C0num*zqt!x0num) mod phi, x0den);
    phi:=phi+Cnum;
//print "nova h", i, testh(P`Type,phi,Pol);
end for;
P`Type[ord]`Phi:=PolynomialRing(Integers())!phi;
if UPD then
    P`sfl[3]:=Max([h,path[#path-1]]);
    P`Phiadic[4]:=x0num;
    P`sfl[4]:=x0den;
    UpdateLastLevel(~P,Pol);
end if;
end intrinsic;

///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

intrinsic testh(type,phi,p,Pol) -> RngIntElt
{}

newphi:=PolynomialRing(Integers())!phi;
print "newphi", newphi;
qq,a0:=Quotrem(Pol,newphi);
if a0 eq 0 then 
    slope:=Infinity();
else    
    sides:=[];
    devs:=[* *];
    phiadic:=[a0,qq mod newphi];
    ty:=type;
    Newton(#ty,~ty,~phiadic,p,~sides,~devs);
    slope:=-Integers()!sides[1,1];
end if;
return slope;
end intrinsic;

///////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////

intrinsic SFL(~P::Rec,slope::RngIntElt: update:=false)
{Given a prime ideal P in a number field, improve its Okutsu approximation phi_(r+1) until P`Type[r+1]`slope>=slope. 
If update=true, the last level of P`Type is updated with data of the new Okutsu approximation.
}

SFL(~P,slope,DefiningPolynomial(P`Parent): UPD:=update);
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic SFLInitialize(~P,Pol)
{Initialize certain values of the given type, which are necessary for the SFL routine.}

p:=P`IntegerGenerator;
r:=#P`Type;
e:=P`Type[r]`prode;
a1:=P`Phiadic[2];
Psinum:=PolynomialRing(Integers())!1;
if r eq 1 then
    nu:=Min([Valuation(x,p): x in Coefficients(a1)]);
    class:=Evaluate(a1 div p^nu,P`Type[1]`z);
else
    val:=0;
    dev:=[* *];
    Value(r,~P`Type,~a1,p,~dev,~val);
    respol:=0;
    ResidualPolynomial(r-1,~P`Type,p,~dev,~respol);
    logpsi:=0;
    qq,s:=Quotrem(-val,e);
    PrescribedValue(~P`Type,s,~Psinum,~logpsi);
    nu:=-logpsi[1]-qq;
    vector:=dev[#dev,1]*P`Type[r-1]`logPhi+dev[#dev,2]*P`Type[r-1]`logPi;
    class:=0;
    ConvertLogs(~P`Type,logpsi+vector,~class);
    class*:=Evaluate(respol,P`Type[r]`z);
end if;
P`sfl[2]:=nu;
P`sfl[3]:=1;
//x0num:=0;
//x0den:=0;
LocalLift(~P`Type,p,class^(-1),~P`Phiadic[4],~P`sfl[4]);
//P`Phiadic[4]:=x0num;
//P`sfl[4]:=x0den;
P`Phiadic[5],P`Phiadic[6]:=FaithfulpAdicConversion(Pol,p);
P`Phiadic[3],P`Phiadic[7]:=FaithfulpAdicConversion(Psinum,p);
end intrinsic;

///////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Shrink(~beta,~P,m)
{Replace beta by an element num/p^power congruent to beta mod P^m such that 
num is given by a polynomial of degree < e_Pf_P, 
The element beta is assumed (without checking) to be P-integral. 
}

require m gt 0: "the third argument must be positive";
require beta in P`Parent: "number fields of first and second argument do not coincide";
p:=P`IntegerGenerator;
den,exp,num:=Localize(beta,p);
beta:=P`Parent!0;
precision:=Ceiling(m/P`e)-exp;
if precision gt 0 then
    power:=p^precision;
    SFL(~P,precision*P`e-P`Type[#P`Type]`V);
    phi:=P`Type[#P`Type]`Phi mod power;
    num:=(InverseMod(den,power)*num mod phi) mod power;
//    beta:=Evaluate(num,P`Parent.1)*p^exp;  
    beta:=P`Parent!Eltseq(num)*p^exp;  
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Taylor(pol::RngUPolElt,phi::RngUPolElt,omega::RngIntElt)->SeqEnum
{Compute the first omega+1 coefficients of the phi-expansion of pol}
quot:=pol;
Coeffs:=[];
for j:=0 to omega do 
  	quot,rem:=Quotrem(quot,phi);
  	Append(~Coeffs,rem);
end for;
return Coeffs;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic TreeInterval(~P,~tree)
{Returns the interval of positions in K`PrimeIdeals[p] of the tree to which O belongs.}

treenumber:=#P`Parent`TreesIntervals[P`IntegerGenerator];
while P`Parent`TreesIntervals[P`IntegerGenerator,treenumber,1] gt P`Position do
    treenumber-:=1;
end while;
tree:=P`Parent`TreesIntervals[P`IntegerGenerator,treenumber];
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic TrueDiscriminant(K::FldNum)->RngIntElt, SeqEnum
{Compute the discriminant (and its factorization) of the maximal order ZK of K. }

if not assigned K`Discriminant then 
    if assigned K`FactorizedDiscriminant then 
	d:=&*[x[1]^x[2]: x in K`FactorizedDiscriminant];
    else
	d:=Discriminant(DefiningPolynomial(K));
	K`FactorizedDiscriminant:=Factorization(d);
    end if;
    primelist:=[x[1]: x in K`FactorizedDiscriminant];
    for p in primelist do 
	Montes(K,p); 
	d:=d div p^(2*K`LocalIndex[p]);
    end for;
    K`Discriminant:=d;
end if;
return K`Discriminant, K`FactorizedDiscriminant;
end intrinsic;

///////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic UpdateLastLevel(~P,Pol)
{Updates the values of slope, h, psi and logGamma in the last level of P`Type.
Also, it updates P`Phiadic[1]=a0 and P`Phiadic[2]=a1.
}

r:=#P`Type;
qq,a0:=Quotrem(Pol,P`Type[r]`Phi);
if a0 eq 0 then 
    P`Type[r]`slope:=Infinity();
else    
    P`Phiadic[1]:=a0;
    P`Phiadic[2]:=qq mod P`Type[r]`Phi;
    sides:=[];
    devs:=[* *];
    phiadic:=[a0,P`Phiadic[2]];
    Newton(r,~P`Type,~phiadic,P`IntegerGenerator,~sides,~devs);
    P`Type[r]`slope:=-sides[1,1];
    P`Type[r]`h:=-Integers()!sides[1,1];
    psi:=0;
    ResidualPolynomial(r,~P`Type,P`IntegerGenerator,~devs[1],~psi);
    P`Type[r]`psi:=psi/LeadingCoefficient(psi);
    P`Type[r]`logGamma:=P`Type[r]`logPhi-P`Type[r]`h*P`Type[r]`logPi;
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////


intrinsic Value(i,~type,~pol,p,~devs,~val)
{Given a level i, a type and a polynomial pol, compute:
- devs=multiexpansion with respect to phi_1,...,phi_i-1 of the points in S_lambda_i-1(pol);
- val=i-th valuation of pol with respect to type.}

require i le #type+1: "the first input is too large";
val:=Infinity();
if pol eq 0 then
    if i eq 1 then
	  devs:=0;
    else
	  devs:=[];
    end if;
    return;
end if;
if i eq 1 then 
    val:=Min([Valuation(c,p): c in Coefficients(pol)]);
    devs:=pol;
else  
    im1:=i-1;
    step:=type[im1]`V+type[im1]`slope;
    minheight:=0;
    twoe:=2*type[im1]`e;
    quot:=pol;
    k:=0;
    last:=0;
    dev:=[* *];
    newval:=0;
    if im1 eq 1 then 
	zero:=0;
    else
	zero:=[];
    end if;
    while quot ne 0 and minheight le val do
	quot,ak:=Quotrem(quot,type[im1]`Phi);
        Value(im1,~type,~ak,p,~dev,~newval);
	candidate:=newval+minheight;
	if candidate le val then
	    if candidate lt val then
		val:=candidate;
		firstabscissa:=k;
		devs:=[* dev *];
	    else  
	    for jj:=last+twoe to k by type[im1]`e do;
		Append(~devs,zero);
	    end for;
	    Append(~devs,dev);
	    end if;
      	last:=k;
	end if;
	minheight+:=step;
	k+:=1;
    end while;
    Append(~devs,[firstabscissa,Integers()!(val-firstabscissa*type[im1]`slope)]);
    val:=Integers()!(type[im1]`e*val);
end if;
end intrinsic;

//////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic VValuation(pol:: RngUPolElt,poly:: RngUPolElt)->RngIntElt
{}
ord:=-1;
rem:=0;
pl:=pol;
while rem eq 0 do
    pl,rem:=Quotrem(pl,poly);
    ord+:=1;
end while;
return ord;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////

intrinsic Z(~type,i,~z)
{The primitive element z_i of the i-th residual finite field F_(i+1) of the type 
is stored in the variable z.}

if i eq #type then 
    z:=-Coefficient(type[#type]`psi,0);
else
    z:=type[i+1]`z;
end if;
end intrinsic;

/////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//    Functions to  manipulate ideals
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////


intrinsic RationalDenominator(I)->RngIntElt
{The least positive integer a such that aI is included in the maximal order O}

require IsIdealRecord(I): "Argument should be an IdealRecord record"; 
a:=1;
if not IsIntegral(I) then
    for p in RationalRadical(I) do 
	exp:=Min([x[3]/I`Parent`PrimeIdeals[p,x[2]]`e: x in I`Factorization | x[1] eq p]);
	if exp lt 0 then
	    a*:=p^-Floor(exp);
	end if;
    end for;
end if;
return Integers()!a;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic TwoElement(I:: Rec)->SeqEnum
{Compute a pair of elements generating the ideal I.}

TwoElement(~I);
return [I`Parent!I`IntegerGenerator, I`Generator];
end intrinsic;

intrinsic TwoElement(~I:: Rec)
{Compute a pair of elements generating the ideal.}

require IsIdealRecord(I): "Argument should be an IdealRecord record"; 
if assigned I`Generator then
    return;
end if;
a:=RationalDenominator(I);
aI:=ideal(I`Parent,a)*I;
list:=aI`Factorization;
Nums:=[];
precisions:=[];
ig:=1;  // integer generator
denalpha:=I`Parent!1; // denominator of second generator
for p in RationalRadical(aI) do 
    Generators(I`Parent,p);
    ppart:=[P: P in list | P[1] eq p];
    Hp:=Max([P[3]/I`Parent`PrimeIdeals[p,P[2]]`e : P in ppart]);   
    alphap:=&*[I`Parent`PrimeIdeals[p,P[2]]`Generator^P[3]: P in ppart]; 
    if Denominator(Hp) eq 1 then 
	multp:=p;
    else
	multp:=1;
    end if;
    firstp:=p^Ceiling(Hp);
    ig*:=firstp;
    Append(~Nums,Eltseq(Numerator(alphap),Integers()));
    denalpha*:=Denominator(alphap);
    Append(~precisions,firstp*Denominator(alphap)*multp);
end for;
I`IntegerGenerator:=ig/a;
numalpha:=[];
CoeffMatrix:=Transpose(Matrix(Nums));
for i:=1 to Degree(I`Parent) do 
    Append(~numalpha,CRT(RowSequence(CoeffMatrix)[i],precisions)); 
end for;
I`Generator:=I`Parent!numalpha/(a*denalpha);
end intrinsic;

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

intrinsic IsIdealRecord(I::Rec)->BoolElt
{True iff I is a record of type IdealRecord.}
return    Names(I) eq Names(rec<IdealRecord|>);
end intrinsic;

//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

intrinsic IsPrimeIdeal(I::Rec)->BoolElt
{True iff I is a record of type IdealRecord corresponding to a prime ideal. }
require IsIdealRecord(I): "Argument should be an IdealRecord record"; 

Factorization(~I);  
return I`IsPrime;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic '*'(I::Rec, J:: Rec)->Rec
{Compute the product  of the  fractional ideals I,J. They are both factored if 
their factorization is not yet known.}

require IsIdealRecord(I): "First argument is not an IdealRecord record";
require IsIdealRecord(J): "Second argument is not an IdealRecord record";
require I`Parent eq J`Parent: "Ideals do not belong to the same number field";
if IsZero(I) or IsOne(J) then 
    return I; 
end if;
if IsZero(J) or IsOne(I) then 
    return J; 
end if;
list:= Sort(Factorization(I) cat Factorization(J));
tot:=#list;
output:=[];
pos:=1;
while pos le tot do    
    i:=pos+1;
    term:=list[pos];
    if (i le tot and list[i,1] eq term[1] and list[i,2] eq term[2]) then 
        term[3]+:=list[i,3];
        i+:=1;
    end if;
    if term[3] ne 0 then
	Append(~output,term);
    end if;
    pos:=i;
end while;
if #output eq 1 and output[1,3] eq 1 then
    return I`Parent`PrimeIdeals[output[1,1],output[1,2]];
end if;
id:= rec<IdealRecord|  Factorization:= output,
                       FactorizationString:= FactorListToString(output), 
                       Parent:=I`Parent,
                       IsPrime:=false>;
if #output eq 0 then 
    id`IntegerGenerator:=1;
    id`Generator:=I`Parent!0;
end if;
return id;
end intrinsic;

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////

intrinsic '^'(I::Rec, n::RngIntElt)->Rec
{Compute the n-th power of the fractional ideal I. The ideal I is factored 
if its factorization is not  known.}

require IsIdealRecord(I): "Argument is not an IdealRecord record";
require not IsZero(I) or n ge 0 : "The zero ideal is not invertible";
if IsZero(I) or IsOne(I) or n eq 1 then 
    return I; 
end if;
if n eq 0 then return  rec<IdealRecord|
    Parent:=I`Parent, IsPrime:=false,
    Generators:=[I`Parent!1], Generator:=I`Parent!0, IntegerGenerator:=1, 
    Factorization:=[], FactorizationString:="" >; 
end if;
l:=Factorization(I);
for i in [1..#l] do 
    l[i,3]:=n*l[i,3]; 
end for;
if #l eq 1 and l[1,3] eq 1 then
    return I`Parent`PrimeIdeals[l[1,1],l[1,2]];
end if;
id:= rec<IdealRecord|
    Parent:=I`Parent, IsPrime:=false, 
    Factorization:=l, FactorizationString:=FactorListToString(l)>;
return id;
end intrinsic;

////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////

intrinsic '/'(I::Rec ,J:: Rec)->Rec
{Compute the quotient of the fractional ideals I,J. They are both factored 
if their factorization is not  knwon.}

require IsIdealRecord(I): "First argument is not an IdealRecord record";
require IsIdealRecord(J): "Second argument is not an IdealRecord record";
require I`Parent eq J`Parent: "Ideals do not belong to the same number field";
require not IsZero(J): "Second argument should be a non-zero ideal.";
if IsZero(I) or IsOne(J) then 
    return I; 
end if;
return I*(J^-1);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
intrinsic IsIntegral(I::Rec )-> BoolElt
{True iff I is an integral ideal. The ideal is factored if its 
factorization is not known.}

require IsIdealRecord(I): "Argument is not an IdealRecord record";
if IsZero(I) or IsOne(I) then 
    return true; 
end if;
ll:=Factorization(I);
return &and[ll[j,3] ge 0: j in [1..#ll]];
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic IsOne(I::Rec )-> BoolElt
{True iff I is the zero ideal}

require IsIdealRecord(I): "Argument should be an IdealRecord record"; 
return assigned I`IntegerGenerator and I`IntegerGenerator eq 1;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic IsZero(I::Rec )-> BoolElt
{true iff I is the zero ideal}

require IsIdealRecord(I): "Argument should be an IdealRecord record"; 
return assigned I`IntegerGenerator and I`IntegerGenerator eq 0;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic 'eq'(I::Rec ,J:: Rec)-> BoolElt
{True iff the fractional ideals I,J are equal. They are both factored 
if their factorization is not  kwown.}

require IsIdealRecord(I): "First argument is not an IdealRecord record";
require IsIdealRecord(J): "Second argument is not an IdealRecord record";

if IsZero(I) and IsZero(J) then 
    return true; 
end if;
if IsZero(I) or IsZero(J) then 
    return false; 
end if;
return Factorization(I) eq Factorization(J);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic 'subset'(I::Rec ,J:: Rec)-> BoolElt
{True iff the fractional ideal J divides I, i.e., iff I/J is integral. 
Both ideals are factored if their factorization is not yet known.}

require IsIdealRecord(I): "First argument is not an IdealRecord record";
require IsIdealRecord(J): "Second argument is not an IdealRecord record";

if IsZero(I) then 
    return true; 
end if;
if IsZero(J) then 
    return false; 
end if;
return IsIntegral(I/J);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic Norm(I::Rec)->RngIntElt
{Compute the norm of the ideal I.}

require IsIdealRecord(I): "Argument is not an IdealRecord record";
require not IsZero(I): "Argument should be a non-zero ideal.";
n:=1;
K:=I`Parent;
for id in Factorization(I) do
    primid:=K`PrimeIdeals[id[1],id[2]];
    n*:=id[1]^(id[3]*primid`f);
end for;
return n;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic RationalRadical(I::Rec)->SeqEnum
{Compute the rational prime numbers dividing the norm of the ideal I.}

require IsIdealRecord(I): "Argument is not an IdealRecord record";
require not IsZero(I): "Argument must be a non-zero ideal";

return SetToSequence(Set([x[1]: x in Factorization(I)]));
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
intrinsic '+'(I::Rec, J:: Rec)->Rec
{Compute the greatest common divisor of the fractional ideals I,J}

require IsIdealRecord(I): "First argument is not an IdealRecord record";
require IsIdealRecord(J): "Second argument is not an IdealRecord record";
require I`Parent eq J`Parent: "Ideals do not belong to the same number field";

if IsZero(I) then 
    return J; 
end if;
if IsZero(J) then 
    return I; 
end if;
GCD:=rec<IdealRecord| Parent:=I`Parent>;
if assigned I`Generators and assigned J`Generators then
	GCD`Generators:=SetToSequence(Set(I`Generators) join Set(J`Generators));
end if;
a1:=I;
b1:=J;
if not assigned a1`Factorization and assigned b1`Factorization then
    a1,b1:=Explode([b1,a1]);
end if;
if assigned a1`Factorization then
    output:=[];
    primesa1:=[Prune(x): x in a1`Factorization];
    if assigned b1`Factorization then
	primesb1:=[Prune(x): x in b1`Factorization];
        for k in [1..#a1`Factorization] do
	    term:=a1`Factorization[k];
            pos:=Position(primesb1,primesa1[k]);
            if  pos ne 0 then
                exp:=Min(term[3],b1`Factorization[pos,3]);
		              if exp ne 0 then 
		                  term[3]:=exp;
		                  Append(~output,term);
		              end if;
            end if;
        end for;
    else
        // b1 is given by generators
        K:=a1`Parent;
        for x in a1`Factorization do
            exp:=x[3];
            for gen in b1`Generators do
                vp:=PValuation(gen,K`PrimeIdeals[x[1],x[2]]);
                exp:=Min(exp,vp);
            end for;
	        if exp ne 0 then 
		          term:=x;term[3]:=exp;
          	      Append(~output,term);
	        end if;
        end for;
    end if;
    GCD`Factorization:=output ;
    GCD`FactorizationString:=FactorListToString(output);
    if #output eq 1 and output[1,3] eq 1 then
	return I`Parent`PrimeIdeals[output[1,1],output[1,2]];
    end if;
    GCD`IsPrime:=false;
    if #output eq 0 then
	GCD`IntegerGenerator:=1;
	GCD`Generator:=I`Parent!0;
    end if;
end if;
return GCD;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic ideal(K::FldNum, listgen::SeqEnum[FldNumElt] )->Rec
{Define the fractional ideal generated by the elements of listgen.}

require &and[x in K: x in listgen]: "Elements should lie in the given number field.";
id:= rec<IdealRecord|  Generators:=listgen, Parent:=K>;
if &and[x eq 0 : x in listgen] then
    id`IntegerGenerator:=0;
    id`Generator:=K!0;
end if;
return id;   
end intrinsic;

intrinsic ideal(K::FldNum, a:: FldNumElt )->Rec
{Define the principal fractional ideal generated by a}

return ideal(K,[a]);   
end intrinsic;




intrinsic ideal(K::FldNum, a:: RngIntElt )->Rec
{Define the principal fractional ideal generated by the integer a}

return ideal(K,[K!a]);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic Factorization(I::Rec)->SeqEnum
{Compute the decomposition of the fractional ideal I into prime ideals.}

require IsIdealRecord(I): "Argument is not an IdealRecord record";
Factorization(~I);
return I`Factorization;
end intrinsic;

intrinsic Factorization(~I::Rec)
{Compute the decomposition of the fractional ideal I into prime ideals.}

require IsIdealRecord(I): "Argument should be an IdealRecord record.";
require not IsZero(I): "Argument should be a non-zero ideal.";
if not assigned I`Factorization then 
    I`Factorization:=[];
    K:=I`Parent;
    normradicals:=[];
    nums:=[];
    dens:=[];
    betas:=[];
    primes:={};
    for g in I`Generators do
        den:=Denominator(g);
        primes:=primes join Set(PrimeDivisors(den));
        num:=Numerator(g);
        gcd:=GCD(Eltseq(num,Integers()));
        beta:=num/gcd;
        Append(~betas,beta);
        Append(~normradicals,
            gcd*Resultant(PolynomialRing(Integers())!Eltseq(beta,Integers()),DefiningPolynomial(K)));
        Append(~dens,den);
        Append(~nums,gcd);
    end for;

    primes:=Sort(SetToSequence(primes join Set(PrimeDivisors(GCD(normradicals)))));
    for p in primes do
        h1:=[Valuation(x,p): x in nums];
        h2:=[Valuation(x,p): x in dens];
        Montes(K,p);
        for j in [1..#K`PrimeIdeals[p]] do
            P:=K`PrimeIdeals[p,j];
            h:=[PValuation(x,P): x in betas];
            exp:=Min([(h1[i]-h2[i])*P`e+h[i]: i in [1..#h1]]);
            if exp ne 0 then 
                Append(~I`Factorization,[p,j,exp]);
            end if;    
        end for;
    end for;
    I`IsPrime:=false;
    I`FactorizationString:=FactorListToString(I`Factorization);
    if #I`Factorization eq 1 and I`Factorization[1,3] eq 1 then
	Gens:=I`Generators;
	I:=I`Parent`PrimeIdeals[I`Factorization[1,1],I`Factorization[1,2]];
	I`Generators:=Gens;
    end if;
    if #I`Factorization eq 0 then
	I`IntegerGenerator:=1;
	I`Generator:=I`Parent!0;
    end if;
end if;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic FactorListToString(list)->MonStgElt
{Write down a factorization in pretty form. }
if #list eq 0 then return ""; end if;
str:="";
for x in list do
  str:=str cat Sprintf( "*P(%o,%o)", x[1],x[2]);
  if x[3] ne 1 then str:=str cat Sprintf("^%o",x[3]); end if;
end for;
return Substring(str,2,#str);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic ResidueField(P::Rec)->FldFin
{Given a prime ideal P, return the residue field Z_K/P}

require IsPrimeIdeal(P): "Argument should be a prime ideal";
t:=P`Type;
return t[#t]`Fq;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
// Functions to generate types                                                                           //
////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////


intrinsic InitializeType(p,psi)-> SeqEnum,SeqEnum,SeqEnum
{Initializa a typelevel record with the given data, and set two lists z, Y
to store the primitive elements of the residual fields and the variables of the 
polynomial rings over these fields.}
t:=[rec<TypeLevel|Prime:=p, V:=0,Phi:=PolynomialRing(Integers())!Coefficients(psi),
    Fq:=ext<GF(p)| psi>,
    prodf:=Degree(psi)>];
t[1]`FqY:=PolynomialRing(t[1]`Fq);    
Y:=[**];
z:=[**];
AssignNames(~(t[1]`FqY),["Y0"] );
Append(~Y,(t[1]`FqY).1);

if Degree(psi) gt 1 then 
        t[1]`z:=Generator(t[1]`Fq);
        mmmm,nnnn:=HasAttribute(t[1]`Fq,"PowerPrinting");
        if mmmm and nnnn then AssertAttribute(t[1]`Fq, "PowerPrinting", false) ; end if;
        AssignNames(~(t[1]`Fq),["z0"] );
    else
        t[1]`z:=Roots(psi)[1,1];        
end if;
Append(~z,t[1]`z);
return t,Y,z;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic EnlargeType( slope,psi,~t,p, ~Y,~z)
{Enlarge the given type t (and the lists Y, z) with the slope -h/e and residual polynomial psi.}

h:=slope[1];
e:=slope[2];
k:=#t;
t[k]`psi:=psi;
t[k]`h:=h;
t[k]`e:=e;
t[k]`slope:=h/e;
t[k]`invh:=InverseMod(h,e);
t[k]`f:=Degree(psi);
H0:=e*t[k]`f*t[k]`V;
H:=H0+h*t[k]`f;
if k gt 1 then
    txp:=-t[k-1]`invh*H0 div t[k-1]`e;
    twist:=t[k]`z^txp;
else
    twist:=t[1]`Fq!1;
end if;
redpsi:=Reductum(psi);

Fq0:=t[k]`Fq;
newpsi:=twist*PolynomialRing(Fq0)!redpsi; 
Phi3:=PolynomialRing(Integers()).1;
Construct(k,~t,p,newpsi,[0,H],~Phi3);
Phi3:=Phi3+t[k]`Phi^(e*t[k]`f); 
Append(~t,rec<TypeLevel|>);
t[k+1]`Phi:=Phi3;
t[k+1]`V:=e*H;

ffa:=Factorization(psi);
t[k+1]`Fq:=ext<Fq0|ffa[1,1]>;
if Degree(psi) gt 1 then
        t[k+1]`z:=Generator(t[k+1]`Fq);
        mmmm,nnnn:=HasAttribute(t[k+1]`Fq,"PowerPrinting");
        if mmmm and nnnn then AssertAttribute(t[k+1]`Fq, "PowerPrinting", false) ; end if;
       AssignNames(~(t[k+1]`Fq),["z" cat Sprint(k)] );
else
        t[k+1]`z:=Roots(psi)[1,1];
end if;
Append(~z,Generator(t[k+1]`Fq));
t[k+1]`FqY:=PolynomialRing(t[k+1]`Fq);
AssignNames(~(t[k+1]`FqY),["Y" cat Sprint(k)] );
Append(~Y,(t[k+1]`FqY).1);
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic CreateType(p,ll)->SeqEnum
{Create a random type t whose invariants [h1,e1,f1,...,hr,er,fr] are specified in the list ll.}
r:=#ll div 3;
s:=Random(2)+1;
fi0:=RandomPrimePolynomial(PolynomialRing(GF(p)),ll[3]);
t,Y,z:=InitializeType(p,fi0);
for j:=1 to r do
    h:=ll[3*j-2];
    e:=ll[3*j-1];
    f:=ll[3*j];
    test:=true;
    while test do
        psi:=RandomPrimePolynomial(PolynomialRing( t[j]`Fq),f);
        if f gt 1 or Coefficient(psi,0) ne CoefficientRing(psi)!0 then test:=false; end if;
    end while;
    vprint montestalk,1: "Psi",Sprint(j), "=",psi;
    EnlargeType([h,e],psi,~t,p,~Y,~z);
end for;
return t;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic CreateRandomType(p,r)->SeqEnum
{Create a random type of order r.}
l:=[];
s:=Random(2)+1;
fi0:=RandomPrimePolynomial(PolynomialRing(GF(p)),s);
t,Y,z:=InitializeType(p,fi0);
for j:=1 to r do
    e:=Random(3)+1;
    h:=Random(10)+1;
    d:=GCD(e,h);
    e:=Integers()!(e/d); h:=Integers()!(h/d);
    f:=Random(2)+1;
    if (e*f eq 1) then f:=f+1; end if;
    test:=true;
    while test do
        psi:=RandomPrimePolynomial(PolynomialRing( t[j]`Fq),f);
        if f gt 1 or Coefficient(psi,0) ne CoefficientRing(psi)!0 then test:=false; end if;
    end while;
    vprint montestalk,1: "Psi",Sprint(j), "=",psi;
    EnlargeType([h,e],psi,~t,p,~Y,~z);
end for;
return t;
end intrinsic;

//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////

intrinsic RandomMultiplicityType(p,r,s)->RngUPolElt
{Creates a random type of depth r and randomly combines s of its phi-polynomials,
adding some random refinements. The full type is always included.}
t:=CreateRandomType(p,r);
pol:=t[#t]`Phi;
for j in [1..s-1] do
    k:=Random(1,r);
    pol:=pol*t[k]`Phi; 
end for;
return pol;
end intrinsic;


//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic CreateRandomMultipleTypePolynomial(p,k,r,s)->RngUPolElt
{Compute a random irreducible polynomial with k types of order AT MOST r. 
The value of s is used to add a power of p to ensure irreducibility. } 
l:=[];
t:=1;
for j:=1 to k do
    Append(~l,CreateRandomType(p,Random(1,r)));
    end for;
pol:=&*[t[r]`Phi: t in l]+p^s;
while not IsIrreducible(pol) do pol:=pol+p^s; end while;
return pol;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic CombineTypes(listoftypes::SeqEnum,p)->RngUPolElt
{Compute and irreducible polynomial whose attached types are the given ones in the specified list.}
pol:=&*[t[#t]`Phi: t in listoftypes];
pp:=p^20;
while not IsIrreducible(pol) do pol:=pol+pp^20; end while;
return pol;
end intrinsic;

//////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////

intrinsic CombinePolynomialsWithDifferentPrimes(f1,p1,f2,p2,k)->RngUPolElt
{Compute a polynomial which is congruent to the given polynomials f1, f2 modulo the
specified powers of the primes p1, p2 }
c1:=Coefficients(f1);
c2:=Coefficients(f2);
cc:=[CRT([c1[j],c2[j]],[p1^k,p2^k]):  j in [1..Degree(f1)+1]];
pol:=PolynomialRing(Integers())!cc;
return pol;
end intrinsic;


//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////
//
// Funcions de formateig
//
//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////

intrinsic GlobalExpansion(Pol,t)->List
{Compute the coefficients of the multi-phi-adic expansion of pol. They are stored in a recursive list.}
k:=#t;
Phi:=t[k]`Phi;
m:=Floor(Degree(Pol)/Degree(Phi));
quot:=Pol;
Coeffs:=[* *];
        for j:=0 to m do 
  		    quot,rem:=Quotrem(quot,Phi);
  		    Append(~Coeffs,rem);
        end for;
if k gt 1 then
       tt:=Prune(t);  
       for j in [1..m+1]  do
           Coeffs[j]:= GlobalExpansion(Coeffs[j],tt);
       end for;
end if;
return Coeffs;
end intrinsic;


intrinsic Expand(coeffslist,t)->RngUPolElt
{This function is only useful to check the validity of expansions given by GlobalExpand.}
if #coeffslist eq 0 then pol:=0;
else
    k:=#t;
    Phi:=t[k]`Phi;
    
    if k eq 1 then 
         pol:=&+[coeffslist[j]*Phi^(j-1): j in [1..#coeffslist]];
    else 
     tt:=Prune(t);
     pp:=0;
     cc:=[**];
             for j in [1..#coeffslist] do
                    pp:=Expand(coeffslist[j],tt);                    
                    Append(~cc,pp);
             end for;   
             pol:=&+[cc[j]*Phi^(j-1): j in [1..#coeffslist]];
             
    end if;
end if;
return pol;
end intrinsic;

////////////////////////////////////////////////////////////////////////
//  Funcions per escriure TeX
////////////////////////////////////////////////////////////////////////

intrinsic ExpandTeX(pol,t)->Str 
{Write in TeX form the multi-phi-adic expansion of pol}
coeffslist:=GlobalExpansion(pol,t);
return ExpandTeXAux(coeffslist,t);
end intrinsic;

intrinsic ExpandTeXAux(coeffslist,t,p)->Str
{}
len:=#coeffslist;
if len eq 0 then polstr:="0";
else
    k:=#t;
    Phi:=t[k]`Phi;

    polstr:="";
    if k eq 1 then 
           for j:=len to 1 by -1 do
             if coeffslist[j] ne 0 then 
               if Degree(coeffslist[j]) eq 0  then
                    ss:=Valuation(Integers()!coeffslist[j],p);cc:=Rationals()!coeffslist[j]/p^ss;
//                    if ss eq 0 then stcc:="1"; else stcc:=Sprint(p) cat "^{" cat Sprint(ss) cat"}" ; end if;
                    if ss eq 0 then stcc:="1"; else stcc:= "p^{" cat Sprint(ss) cat"}" ; end if;
                    if cc ne 1 then stcc:=stcc cat "\\cdot" cat Sprint(cc); end if;
                    
                else
                    stcc:=Sprint(coeffslist[j]);    
                end if;    
                polstr:=polstr cat "(" cat stcc  cat ")";
                if j gt 2 then polstr:=polstr cat "\\phi_" cat Sprint(k-1) cat "^{" cat Sprint(j-1) cat "}+"; end if;
                if j eq 2 then polstr:=polstr cat "\\phi_" cat Sprint(k-1) cat "+"; end if;
             end if;       
           end for;  
    else 
         tt:=Prune(t);
         pp:="";
         cc:=[];
         for j in [1..len] do
                    pp:=ExpandTeXAux(coeffslist[j],tt);
                    Append(~cc,pp);
         end for;   
         for j:=len to 1 by -1 do
             if cc[j] ne "0" then 
                polstr:=polstr cat "(" cat cc[j] cat ")";
                if j gt 2 then polstr:=polstr cat "\\phi_" cat Sprint(k-1) cat "^{" cat Sprint(j-1) cat "}+";  end if;
                if j eq 2 then polstr:=polstr cat "\\phi_" cat Sprint(k-1) cat "+"; end if;
             end if;       
           end for;           
    end if;
    lp:=#polstr;
    if polstr[lp] eq "+" then polstr:=Substring(polstr,1,lp-1); end if;
    if polstr[lp-1] eq "+" then polstr:=Substring(polstr,1,lp-2) cat ")"; end if;
end if;
return polstr;
end intrinsic;






intrinsic ExpandPhiTeX(k,t,p)->Str
{Write the phi-adic expansion of phi_k in TeX format}
polstr:="";
if k eq 0 then 
        coeffslist:=Coefficients(t[1]`Phi);
        len:=#coeffslist;
        for j:=len to 1 by -1 do
             if coeffslist[j] ne 0 then 
                    ss:=Valuation(Integers()!coeffslist[j],p);cc:=Rationals()!coeffslist[j]/p^ss;
                    if ss eq 0 then stcc:="1"; else stcc:=Sprint(p) cat "^{" cat Sprint(ss) cat"}" ; end if;
                    if cc ne 1 then stcc:=stcc cat "\\cdot" cat Sprint(cc); end if;
             else stcc:="0";
             end if;    
                polstr:=polstr cat "(" cat stcc  cat ")";
                if j gt 2 then polstr:=polstr cat "x" cat  "^{" cat Sprint(j-1) cat "}+"; end if;
                if j eq 2 then polstr:=polstr cat "x" cat  "+"; end if;
        end for;  
else 
    pol:=t[k+1]`Phi;
    t1:=[t[j]: j in [1..k] ];
    polstr:=ExpandTeX(pol,t1);
end if;    
return "\\phi_" cat Sprint(k) cat "=" cat polstr cat ";";
end intrinsic;


intrinsic ExpandAllPhiTeX(t)->Str 
{Write in TeX format the phi-adic expansion of all the phi in the type}
polstr:="\\phi_0=" cat ExpandPhiTeX(0,t);
for k in [2..#t] do
    st:="\\phi_" cat Sprint(k-1) cat "=" cat  ExpandPhiTeX(k-1,t);
    polstr:=polstr cat "\\\\" cat st;
end for;
return polstr;
end intrinsic;




////////////////////////////////////////////////////////////////////////
//  Funcions per escriure Magma
////////////////////////////////////////////////////////////////////////

intrinsic ExpandMagma(pol,t)->Str
{Write in Magma form the multi-phi-adic expansion of pol}
coeffslist:=GlobalExpansion(pol,t);
return ExpandMagmaAux(coeffslist,t);
end intrinsic;

intrinsic ExpandMagmaAux(coeffslist,t,p)->Str
{}
len:=#coeffslist;
if len eq 0 then polstr:="0";
else
    k:=#t;
    Phi:=t[k]`Phi;
    polstr:="";
    if k eq 1 then 
           for j:=len to 1 by -1 do
             if coeffslist[j] ne 0 then 
               if Degree(coeffslist[j]) eq 0  then
                    ss:=Valuation(Integers()!coeffslist[j],p);cc:=Rationals()!coeffslist[j]/p^ss;
//                    if ss eq 0 then stcc:="1"; else stcc:=Sprint(p) cat "^" cat Sprint(ss)  ; end if;
                    if ss eq 0 then stcc:="1"; else stcc:= "p^" cat Sprint(ss)  ; end if;
                    if cc ne 1 then stcc:=stcc cat "*" cat Sprint(cc); end if;
                    
                else
                    stcc:=Sprint(coeffslist[j]);    
                end if;    
                polstr:=polstr cat "(" cat stcc  cat ")";
                if j gt 2 then polstr:=polstr cat "*phi" cat Sprint(k-1) cat "^" cat Sprint(j-1) cat "+"; end if;
                if j eq 2 then polstr:=polstr cat "*phi" cat Sprint(k-1) cat "+"; end if;
             end if;       
           end for;  
    else 
         tt:=Prune(t);
         pp:="";
         cc:=[];
         for j in [1..len] do
                    pp:=ExpandMagmaAux(coeffslist[j],tt);
                    Append(~cc,pp);
         end for;   
         for j:=len to 1 by -1 do
             if cc[j] ne "0" then 
                polstr:=polstr cat "(" cat cc[j] cat ")";
                if j gt 2 then polstr:=polstr cat "*phi" cat Sprint(k-1) cat "^" cat Sprint(j-1) cat "+";  end if;
                if j eq 2 then polstr:=polstr cat "*phi" cat Sprint(k-1) cat "+"; end if;
             end if;       
           end for;           
    end if;
    lp:=#polstr;
    if polstr[lp] eq "+" then polstr:=Substring(polstr,1,lp-1); end if;
    if polstr[lp-1] eq "+" then polstr:=Substring(polstr,1,lp-2) cat ")"; end if;
end if;
return polstr;
end intrinsic;


intrinsic ExpandPhiMagma(k,t)->Str 
{Write the phi-adic expansion of phi_k in Magma format}
if k eq 0 then return Sprint(t[1]`Phi);
else 
    pol:=t[k+1]`Phi;
    t1:=[t[j]: j in [1..k] ];
    return ExpandMagma(pol,t1);
end if;    

end intrinsic;


intrinsic ExpandAllPhiMagma(t)->Str
{Write in Magma format the phi-adic expansion of all the phi in the type}
polstr:="";
for k in [1..#t] do
    st:=ExpandPhiMagma(k-1,t);
    st:="phi" cat Sprint(k-1) cat ":=" cat st cat ";          ";
    polstr:=polstr cat st;
end for;
return polstr;
end intrinsic;


///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/*  Functions addressed to the users, pending of revision

intrinsic Value(r,type,pol,p) -> RngIntElt
{Given an order r, a type and a polynomial pol, compute
the r-th valuation of pol with respect to the type.
}

sides:=Newton(r,type,pol,p);
PrincipalPart:=[x : x in sides | x[1] lt 0];
k:=#PrincipalPart;
if k gt 0 then
    return Integers()!PrincipalPart[k,5];
else
    return Integers()!PrincipalPart[k+1,3];
end if;
end intrinsic;


intrinsic Newton(r,type,pol,p) -> SeqEnum
{Given a type of order at least r, and a polynomial pol, compute the
list of sides of the r-th order Newton polygon with respect to the type.
}
phiadic:=Taylor(pol,type[r]`Phi,Floor(Degree(pol)/Degree(type[r]`Phi)));
sides:=[];
devs:=[* *];
Newton(r,~type,~phiadic,p,~sides,~devs);
return sides;
end intrinsic;

intrinsic ResidualPolynomial(r::RngIntElt, type::SeqEnum, Pol::RngUPolElt,p)->RngUPolElt 
{Compute the r-th residual polynomial of Pol with respect to a type.
}

phiadic:=Taylor(Pol,type[r]`Phi,Floor(Degree(Pol)/Degree(type[r]`Phi)));
sides:=[];
devs:=[* *];
Newton(r,~type,~phiadic,p,~sides,~devs);
previous:=[x: x in sides | -x[1] gt type[r]`slope];
k:=#previous;
if k eq #sides then
    dev:=[* devs[k,#devs[k]-1],[Integers()!sides[k,4],Integers()!sides[k,5]] *];
else
    if sides[k+1,1]=-type[r]`slope then
	dev:=devs[k+1];
    else
	dev:=[* devs[k+1,1],[Integers()!sides[k+1,2],Integers()!sides[k+1,3]] *];
    end if;
end if;
psi:=0;
ResidualPolynomial(r,~type,p,~dev,~psi);
return psi;
end intrinsic;


intrinsic Construct(r,type,p,respol,V) -> RngUPolElt
{This routine works out the construction of [HN, Prop. 2.10].
V is a positive integer >= type[r+1]`V. 
respol is a polynomial in type[r]`FqY of degree < type[r]`f.
The output is a polynomial Ppol with integer coefficients such that: 
deg Ppol<m_r+1, v_r+1(Ppol)=V, and y^nu·R_r(Ppol)(y)=respol(y), 
where nu=ord_y(respol).}

s:=type[r]`invh*V mod type[r]`e;
u:=(V-type[r]`h*s) div type[r]`e;
Ppol:=0;
Construct(r, ~type,p, respol, [s,u], ~Ppol);
return Ppol;
end intrinsic;




*/



////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Begin IdealsBasis
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Local bases


intrinsic pBasis(I::Rec, p::RngIntElt : HNF:=false, Separated:=false) -> SeqEnum
    { Computes a p-integral basis of the fractional ideal }
      
    nums, dexp, a := pBasisTriangular(I, p);

    if HNF eq true then
        basis := HermiteFormBasis(I`Parent, p, nums, dexp);

        nums := [ PolynomialRing(Integers())!Eltseq(Numerator(b)) : b in basis ];
    else
        K := I`Parent;
        basis := Reverse([ (K![ Coefficient(nums[i], j)
                            : j in [0..#nums-1] ])/K!p^dexp[i]
                                : i in [#nums..1 by -1] ]);
    end if;

    if Separated eq false then
        pa := Rationals()!p^a;
        return [ g*pa : g in basis ];
    else
        return nums, [ exp - a : exp in dexp ];
    end if;

end intrinsic; // pBasis

intrinsic pBasis(K::FldNum, p::RngIntElt : HNF:=true, Separated:=false)->SeqEnum
    { Returns a p-basis of the maximal order. }

    return pBasis(ideal(K, K!1), p : HNF:=HNF, Separated:=Separated);
end intrinsic; // pBasis

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

intrinsic pBasisTriangular(I::Rec, p::RngIntElt) -> SeqEnum, SeqEnum, RngIntElt
    { Computes a p-integral basis of the fractional ideal }
      
	K	:=	I`Parent;
    Montes(K, p);
    Factorization(~I);

    ideal_exp, a := reduceIdeal(I, p : exponents:=true);

    basis, nums, dexp := MaxMin(K, p, ideal_exp);

    return nums, dexp, a;
end intrinsic; // pBasisTriangular

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

intrinsic reduceIdeal(I::Rec, p::RngIntElt : exponents:=false)-> Rec, RngIntElt
    { Returns a new ideal J and exponent a such that I = p^a J. }

    Primes := I`Parent`PrimeIdeals[p];
    s := #Primes;

    //Initializing Exponentes of p-part of ideal
    Expos:=[0:i in [1..s]];
    for i in I`Factorization do
        if i[1] eq p then 	
            Expos[i[2]]:=i[3];
        end if;
    end for;

    //Ziehe groessten p(t)^a*O_F aus I heraus und speicher p(t)^a 
    a := 0;
    if forall{i:i in [1..s]|Expos[i] gt 0 } then
        a:=Minimum([Floor(Expos[ll]/Primes[ll]`e):ll in [1..s]]);
        Expos:=[Expos[ll]-Primes[ll]`e*a:ll in [1..s]];
    end if;
    if forall{i:i in [1..s]|Expos[i] lt 0 } then
        a:=Maximum([Ceiling(Expos[ll]/Primes[ll]`e):ll in [1..s]]);
        Expos:=[Expos[ll]-Primes[ll]`e*a:ll in [1..s]];
    end if;

    J := &*[ I`Parent`PrimeIdeals[p,i]^Expos[i] : i in [1..s] ];

    if exponents eq true then
        return Expos, a;
    else
        return J, a;
    end if;
end intrinsic; // reduceIdeal

intrinsic HermiteFormBasis(K::FldNum, p::RngIntElt, nums::SeqEnum, dexp::SeqEnum)-> SeqEnum
    { }

    n := Degree(K);
    maxexp := dexp[n];
    p_max := p^maxexp;
    Nums := [ [ Coefficient(nums[i], j) * p^(maxexp-dexp[i])
                :  j in [n-1..0 by -1] ]
                    : i in [n..1 by -1] ];

    Zp := pAdicRing(p, maxexp+1);
    pi := UniformizingElement(Zp);
    matrix_red := Matrix(Zp, Nums);
    hnf_matrix := HermiteForm(matrix_red);

    hnf_basis := Reverse([ K!Reverse(Eltseq(hnf_matrix[i]))/p_max :
                                i in [1..n] ]);

    return hnf_basis; 
end intrinsic; // HermiteFormBasis

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Global bases

intrinsic IndexPrimeFactors(K::FldNum)
    {}

    if assigned K`IndexPrimeFactors then
        return;
    end if;

    if not assigned K`FactorizedDiscriminant then
        K`FactorizedDiscriminant := Factorization(Discriminant(DefiningPolynomial(K)));
    end if;

    primes := [ f[1] : f in K`FactorizedDiscriminant | f[2] gt 1 ];
    list := [ ];
    for p in primes do
        Montes(K, p);
        if K`LocalIndex[p] gt 0 then
            Append(~list, p);
        end if;
    end for;

    K`IndexPrimeFactors := list;

end intrinsic; // IndexPrimeFactors


intrinsic IdealBasis(I::Rec : HNF:=false, Separated:=false)->SeqEnum
    { Compute a (Hermitian) basis of the ideal I. }

	K:=I`Parent;
    IndexPrimeFactors(K);
    
    primes := SetToSequence(Set(RationalRadical(I) cat K`IndexPrimeFactors));
    if primes eq [] then
    	return [K.1^i:i in [0..Degree(K)-1]],1;
    end if;

    basis, factor := SIdealBasis(I, primes);

    if HNF eq true then
        basis := HermiteFormBasis(K, basis);
    end if;

    if Separated eq false then
        return [ g*factor : g in basis];
    else
        return basis, factor;
    end if;
end intrinsic;

intrinsic SIdealBasis(I::Rec, primelist::SeqEnum)-> SeqEnum
    { Compute a local integral basis of I for the given set of primes. }

    K := I`Parent;
    Factorization(~I);
    n := Degree(K);
    Numlist := [];
    Denlist := [];
    DenCRTlist := [];
    factor := 1;


    if #primelist eq 0 then
        return [K.1^k: k in [0..n-1]];
    end if;

    for p in primelist do

        Montes(K, p);

        nums, dexp, pexp := pBasisTriangular(I, p);
        factor *:= K!p^pexp;

        dens := [ Rationals()!p^e : e in dexp ];
        p_factors := [ fac : fac in I`Factorization | fac[1] eq p ];
        if #p_factors gt 0 then
            alpha := Maximum([ Ceiling(fac[3]/K`PrimeIdeals[p,fac[2]]`e)
                                            : fac in p_factors ]);
        else
            alpha := 0;
        end if;
        dens_crt := [ p^(Maximum(alpha, 0)+Maximum(e+1, 0)) : e in dexp ];

        Append(~Numlist, [ Coefficients(g) : g in nums ]);
        Append(~Denlist, dens);
        Append(~DenCRTlist, dens_crt);
    end for;

    SBasis := [ K | ];

    for i := 1 to n do
        Dens := [ Denlist[k, i] : k in [1..#primelist] ];
        DensCRT := [ DenCRTlist[k,i] : k in [1..#primelist] ];
        coeffs := [];
        for j := 1 to i-1 do
            Nums := [Numlist[k, i, j] : k in [1..#primelist]];
            Append(~coeffs, CRT(Nums, DensCRT));
        end for;
        coeffs cat:= [0: j in [1..n-#coeffs]];
        Append(~SBasis, (K.1^(i-1)+K!coeffs)/&*Dens);
    end for;

    return SBasis, factor;
end intrinsic; // SIdealBasis


intrinsic HermiteFormBasis(K::FldNum, basis::SeqEnum)-> SeqEnum
    { We assume that the (global) basis is triangular. }

    n := #basis;
    dens := [ Denominator(g) : g in Reverse(basis) ];
    maxden := dens[1];

    A := Matrix(Integers(), [ Reverse(Eltseq(g*maxden, Rationals()))
                        : g in Reverse(basis) ]);
    H := HermiteForm(A);

    hnf_basis := [ K!Reverse(Eltseq(H[i]))/maxden : i in [n..1 by -1] ];

    return hnf_basis;
end intrinsic; // HermiteFormBasis


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// MaxMin
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


intrinsic MaxMinCore(okbasis_values::SeqEnum, modifiers::SeqEnum)-> SeqEnum, SeqEnum, List, List
    { The core of the MaxMin algorithm.
      Input:
        - The $\Q$-value of every element of each Okutsu $\P$-basis for all
          $\P$, $\Q$ in the input set.
        - 
      Output:
        - Indices of final basis elements as product of input bases elements
        - Denominator exponents of each basis element
        - The $\P$-value of each basis element for all input $\P$
        - The required $\P$-value of each Montes approximation to $F_\P$ }

    indices := [ ];
    den_exp := [ExtendedReals()|];
    values := [* *];

    s := #okbasis_values;
    J := [ 1 : i in [1..s] ];
    nps := [ #okbasis_values[i]-1 : i in [1..s] ];
    n := &+[ np : np in nps ];

    approx_values := [* 0 : i in [1..s] *];
    req_approx_values := [* 0 : i in [1..s] *];

    for m := 0 to n do
        S := [ &+[ okbasis_values[k,J[k],i]
                    : k in [1..s] ] - modifiers[i]
                        : i in [1..s] ];
        v, u := Min([ S[i] + approx_values[i] : i in [1..s] ]);

        Append(~den_exp, S[u]);
        Append(~indices, J);
        Append(~values, S);

        // Store the required phi_P values.
        if m lt n then
            for i in [1..s] do
                if approx_values[i] eq Infinity() then
                    o_val := S[i] - okbasis_values[i,J[i],i];
                    req_approx_values[i] := Max(req_approx_values[i],
                                                v - o_val);
                end if;
            end for;
        end if;

        J[u] +:= 1;
        if J[u] gt nps[u] then
            approx_values[u] := Infinity();
        end if;
    end for;

    return indices, den_exp, values, req_approx_values;
end intrinsic; // MaxMinCore


intrinsic MaxMin(K::FldNum, p::RngIntElt, exponents)-> SeqEnum, SeqEnum, SeqEnum
    { }

    s := #K`PrimeIdeals[p];
    ok_frames := calculateOkutsuFramesValues(K`PrimeIdeals[p]);
    bases_indices := [* *];

    nps := [ type`e*type`f : type in K`PrimeIdeals[p] ];
    rs := [ #type`Type : type in K`PrimeIdeals[p] ];

    for i := 1 to s do
        Append(~bases_indices, calculateBasisIndices(K`PrimeIdeals[p,i]));
    end for;
    bases_values := computeBasesValues(bases_indices, ok_frames);
    modifiers := [ exponents[i]/K`PrimeIdeals[p,i]`e : i in [1..s] ];

    // Call MaxMin Core.
    indices, den_exp, values, req_approx_values := MaxMinCore(bases_values,
                                                              modifiers);

    liftMontesApproximations(~K`PrimeIdeals[p], req_approx_values);
    updateOkutsuFrames(~ok_frames, K`PrimeIdeals[p]);

    if #ok_frames eq 1 then
        basis := computeOkutsuBasis(ok_frames[1]);
    else
        mod_exponents := reductionExponents(den_exp[1..#den_exp-1], modifiers);
        basis := computeLocalBasis(indices, bases_indices, ok_frames,
                                   p^mod_exponents[#mod_exponents]);
    end if;

    // Remove the degree n element so we have a non-extended basis.
    basis := basis[1..#basis-1];
    den_exp := den_exp[1..#den_exp-1];

    reducepBasis(~basis, den_exp, modifiers, p);

    den_exp := [ Floor(v) : v in den_exp ];

    p_basis := [ (K![ Coefficient(basis[i], j)
                    : j in [0..#basis-1] ])/K!p^den_exp[i]
                        : i in [#basis..1 by -1] ];


    return Reverse(p_basis), basis, den_exp;
end intrinsic; // MaxMin


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


intrinsic liftMontesApproximations(~types::SeqEnum[Rec], req_phip_vals::List)
    { Increase each $\phi_\P$ so that it's $\P$-value is at least that of
      the corresponding entry in `req_phip_vals`. }

    for i in [1..#req_phip_vals] do
        V := types[i]`Type[#types[i]`Type]`V;
        required_slope := (req_phip_vals[i] * types[i]`e) - V;

        SFL(~types[i], Ceiling(required_slope));
    end for;

end intrinsic; // liftMontesApproximations


intrinsic calculateOkutsuFramesValues(types)-> List
    { Calculate the primary and secondary values for the phi-polynomials of
      the Okutsu frames for all types. }

    type_levels := [#tt`Type - 1 : tt in types ];

    QQ := RationalField();
    values := [ [ [* -1 : j in [1..#types] *]
                : r in [1..#types[i]`Type] ]
                    : i in [1..#types] ];

    for i := 1 to #types do
        lvlsi := types[i]`Type;

        // Calculate primary values.
        for k := 1 to #lvlsi do
            values[i,k,i] := (lvlsi[k]`V + lvlsi[k]`slope)/lvlsi[k]`prode;
        end for;

        // Calculate cross values.
        for j := 1 to i-1 do
            lvlsj := types[j]`Type;

            indco := IndexOfCoincidence(types[i], types[j]);

            if indco gt 0 then
                refi := Append(lvlsi[indco]`Refinements,
                               [* lvlsi[indco]`Phi, lvlsi[indco]`slope *]);
                refj := Append(lvlsj[indco]`Refinements,
                               [* lvlsj[indco]`Phi, lvlsj[indco]`slope *]);
                length := Min(#refi, #refj);
                k := 2;
                while k le length and refi[k,1] eq refj[k,1] do
                    k +:= 1;
                end while;
                cutting_phi := refi[k-1,1];
                slope_i := refi[k-1,2];
                slope_j := refj[k-1,2];
                min_slope := Min(slope_i, slope_j);

                // Calculate the cross values of each $Phi_{k,\P}$ for
                // $k < $\ell$.
                for k := 1 to indco - 1 do
                    values[i,k,j] := values[i,k,i];
                    values[j,k,i] := values[i,k,i];
                end for;

                // Calculate the cross values of each $Phi_{\ell,\P}$.
                min_val := (lvlsi[indco]`V+min_slope)/lvlsi[indco]`prode;
                if cutting_phi eq lvlsj[indco]`Phi then
                    values[j,indco,i] := (lvlsi[indco]`V + slope_i)/
                                                lvlsi[indco]`prode;
                else
                    values[j,indco,i] := min_val;
                end if;
                if cutting_phi eq lvlsi[indco]`Phi then
                    values[i,indco,j] := (lvlsi[indco]`V + slope_j)/
                                                lvlsi[indco]`prode;
                else
                    values[i,indco,j] := min_val;
                end if;

                min_val /:= Degree(lvlsi[indco]`Phi);
            else
                min_val := 0;
            end if;

            // Calculate the cross values of each $Phi_{k,\P}$ for $k > \ell$.
            for k := indco + 1 to #lvlsi do
                values[i,k,j] := Degree(lvlsi[k]`Phi) * min_val;
            end for;
            for k := indco + 1 to #lvlsj do
                values[j,k,i] := Degree(lvlsj[k]`Phi) * min_val;
            end for;


        end for;
    end for;

    // Include the degree of each element of the Okutsu frame and the index of
    // the phi polinomial along with its values.
    ok_frames := [ [ rec<OkutsuFrameLevel|
                            degree:=Degree(types[i]`Type[k]`Phi),
                            index:=k,
                            values:=values[i,k],
                            polynomial:=types[i]`Type[k]`Phi>
                        : k in [1..#types[i]`Type] ]
                            : i in [1..#types] ];

    // If $\phi_1$ has degree greater than 1, add an extra element for the
    // x required to make okutsu basis elements of degree not congruent with 0
    // mod deg(phi_1).
    x := Parent(types[1]`Type[1]`Phi).1;
    theta_values := [* *];
    for i in [1..#types] do
        if ok_frames[i,1]`degree gt 1 then
            if #theta_values eq 0 then
                for j in [1..#types] do
                    phiPj := types[j]`Type[1]`Phi;
                    if Degree(phiPj) eq 1 then
                        a := Coefficient(phiPj, 0);
                        if a eq 0 then
                            nu := types[j]`Type[1]`slope;
                        else
                            nu := Valuation(a, types[j]`IntegerGenerator);
                        end if;
                    else
                        nu := Rationals()!0;
                    end if;
                    Append(~theta_values, nu);
                end for;
            end if;
            Insert(~ok_frames[i], 1, rec<OkutsuFrameLevel|
                                            degree:=1,
                                            index:=0,
                                            values:=theta_values,
                                            polynomial:=x>);
        end if;
    end for;

    return ok_frames;
end intrinsic; // calculateOkutsuFramesValues


intrinsic updateOkutsuFrames(~ok_frames::SeqEnum, types::SeqEnum)
    { }

    for i in [1..#ok_frames] do
        lvlr := types[i]`Type[#types[i]`Type];
        ok_frames[i,#ok_frames[i]]`polynomial := lvlr`Phi;
        ok_frames[i,#ok_frames[i]]`values[i] := (lvlr`V + lvlr`slope)/lvlr`prode;
    end for;

end intrinsic; // updateOkutsuFrames

intrinsic computeOkutsuBasis(frame)-> SeqEnum
    { Efficiently computes the Okutsu basis for the given Okutsu frame. This is
      produced by the canonical product of the $\phi$-polynomials from. }

    basis := [ Parent(frame[1]`polynomial)!1 ];
    
    for m := 2 to Degree(frame[#frame]`polynomial)+1 do
        _, ri := Min([ (m-1) mod frame[r]`degree : r in [#frame..1 by -1] ]);
        r := #frame - ri + 1;
        Append(~basis, basis[m - frame[r]`degree] * frame[r]`polynomial);
    end for;

    return basis;
end intrinsic; // computeOkutsuBasis

intrinsic computeBasisValues(t_ind, t_frame)-> SeqEnum
    { Efficiently computes the values of a basis. }

    // Sanity check.
    if #t_frame eq 0 then
        return [ [0] ];
    end if;

    // "Normalise" the degrees so the first is 1.
    for k in [#t_frame..1 by -1]  do
        t_frame[k]`degree := Integers()!(t_frame[k]`degree/t_frame[1]`degree);
    end for;

    values := [ [ ExtendedReals()| 0 : j in [1..#t_frame[1]`values] ] ];
    for m := 2 to #t_ind do
        v, u := Max([t_ind[m,i]-t_ind[m-1,i] : i in [1..#t_ind[m]]]);
        e_vals := [ExtendedReals()|
                      values[m-t_frame[u]`degree,j] + t_frame[u]`values[j]
                          : j in [1..#t_frame[1]`values] ];
        Append(~values, e_vals);
    end for;

    return values;
end intrinsic; // computeBasisValues

intrinsic computeBasesValues(indices, okutsu_frames)-> List
    { Efficiently computes the values of all Oktusu bases. }

    bases_values := [ ];

    for i in [1..#indices] do
        values := computeBasisValues(indices[i], okutsu_frames[i]);
        Append(~bases_values, values);
    end for;

    return bases_values;
end intrinsic; // computeBasesValues

intrinsic calculateBasisIndices(type::Rec)-> List
    { Calculate the indices that represent basis elements. The 0th indiex is
      the exponent of x (only used if f_0 > 1) then the i-th index is the
      exponent of phi_i,P for the P associated with this type. }

    lvls := type`Type;
    m1 := Degree(type`Type[1]`Phi mod type`IntegerGenerator);
    pools := [ ];

    if m1 gt 1 then
        pools := [ [0..m1-1] ];
    end if;

    pools cat:= [ [0..lvls[r]`e * lvls[r]`f - 1] : r in [1..#lvls-1] ];
    pools cat:= [ [0] ];

    indices := itertoolsProduct(pools);
    Append(~indices, [ 0 : r in [1..#indices[1]-1] ] cat [1]);

    return indices;
end intrinsic; // calculateBasisIndices


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

intrinsic computeLocalBasis(lb_indices, bases_indices, frames, pprec)-> List
    { Efficiently compute a local basis given the indices of which element
      from each $\P$-basis is used to make up an element of the final basis.

      Note: We don't need to compute the Okutsu basis for each $\P$ to do this,
            just the Okutsu frame. }

    s := #frames;
    local_basis := [* PolynomialRing(Integers())!1 *];
    f_bases := [ AssociativeArray() : i in [1..s] ];

    for m := 2 to #lb_indices do
        _, i := Max([lb_indices[m,j]-lb_indices[m-1,j] : j in [1..s]]);
        
        u_ind := lb_indices[m,i];
        _, u := Max([bases_indices[i,u_ind,j] - bases_indices[i,u_ind-1,j]
                            : j in [1..#bases_indices[i,u_ind]]]);
        ch_index := frames[i,u]`index;
        ch_deg := frames[i,u]`degree;

        if u eq 1 then
            basis_el := local_basis[m-1] * frames[i,1]`polynomial;
        elif ch_index eq 1 then
            basis_el := local_basis[m-ch_deg] * frames[i,u]`polynomial;
        else
            not_i := [1..i-1] cat [i+1..s];
//            if &+[ lb_indices[m,j]-lb_indices[m-ch_deg,j] : j in not_i ] eq 0 then
            if lb_indices[m,i] - lb_indices[m-ch_deg,i] eq ch_deg then
                basis_el := local_basis[m-ch_deg] * frames[i,u]`polynomial;
            else
                basis_el := 1;
                for i in [1..#bases_indices] do
                    computeOkutsuBasisElement(~f_bases[i], frames[i],
                                              bases_indices[i],
                                              lb_indices[m,i]);
                    basis_el *:=  f_bases[i,lb_indices[m,i]];
                end for;
            end if;
        end if;

        // We reduce each element mod p^prec where prec is the maximum
        // precision required by the basis. This keeps the precision reasonably
        // low.
        basis_el := basis_el mod pprec;
        Append(~local_basis, basis_el);
    end for;


    return [g : g in local_basis];
end intrinsic; // computeLocalBasis

intrinsic computeOkutsuBasisElement(~basis, frame, indices, m)
    { }

    // basis := AssociativeArray();

    if IsDefined(basis, m) then
        return;
    end if;

    if m eq 1 then
        // Cheating a bit, but this *must* be true.
        basis[m] := PolynomialRing(Integers())!1;
    else
        _, u := Max([ indices[m,j]-indices[m-1,j] : j in [1..#indices[m]] ]);
        computeOkutsuBasisElement(~basis, frame, indices,
                                  m - frame[u]`degree);
        basis[m] := basis[m - frame[u]`degree] * frame[u]`polynomial;
    end if;

end intrinsic; // computeOkutsuBasisElement


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


intrinsic basisFromMatrix(matrix::Mtrx, basis_values, K::FldNum, p::RngIntElt)->SeqEnum
    { Returns a basis comprised of elements from `K`. }

    n := #basis_values;
    
    return [ K![matrix[i,j] : j in [n..1 by -1]]/p^basis_values[n+1-i] : i in [n..1 by -1] ];
end intrinsic; // basisFromMatrix

intrinsic reductionExponents(dexp::SeqEnum, modifiers::SeqEnum)-> SeqEnum
    { Calculate the exponents for reduction modulo p^nu. }

    max_modifier := Maximum(modifiers);
    mod_exponents := [ Maximum(Ceiling(v + max_modifier), 0)+1 : v in dexp ];

    return mod_exponents;
end intrinsic; // reductionExponents

intrinsic reducepBasis(~nums::SeqEnum, dexp::SeqEnum, modifiers::SeqEnum, p::RngIntElt)
    { Reduce all basis numerators mod their valuation. }

    // We can reduce each basis element g modulo p^(w_I(g + max))
    max_modifier := Maximum(modifiers);
    mod_exponents := [ Maximum(Ceiling(v + max_modifier), 0)+1 : v in dexp ];
//    printf "\n(reducepBasis) mod_exponents: %o\n", mod_exponents;
    mods := [ p^mod_exponents[1] ];
    prime_cache := AssociativeArray();
    for i in [2..#mod_exponents] do
        delta := mod_exponents[i] - mod_exponents[i-1];
        j := Index(mod_exponents, delta);
        if j gt 0 then
            delta_power := mods[j];
        elif IsDefined(prime_cache, j) then
            delta_power := prime_cache[j];
        else
            delta_power := p^j;
            prime_cache[j] := delta_power;
        end if;
        
        Append(~mods, mods[i-1] * delta_power);
    end for;

    tmps := Cputime();
    n := #nums;
    Ox := Parent(nums[1]);
    for i in [1..n] do
        coeffs := Parent([p]) ! Eltseq(nums[i]);
        nums[i] := Ox ! [ coeffs[j] mod mods[i] : j in [1..#coeffs] ];
    end for;

end intrinsic; // reducepBasis


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


intrinsic itertoolsProduct(pools)-> List
    { The ugly implementation of the product function from python's itertools. }

    result := [* [] *];

    for pool in Reverse(pools) do
        midresult := [* *];
        for x in result do
            midresult cat:= [* [ y ] cat x : y in pool *];
        end for;
        result := midresult;
    end for;

    return result;
end intrinsic;


