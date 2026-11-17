# Goserelin VMP/AMP Comparison: SNOMED Hierarchy vs dm+d Ingredient

## Summary

This report compares two ways of deriving VMP and AMP products for goserelin:

1. SNOMED CT hierarchy: descendants of `776143000 |Product containing only goserelin (medicinal product)|`
2. dm+d ingredient model: VMPs linked through `vmp_ingredient` to goserelin ingredient records, then AMPs under those VMPs

For the local data tested, both methods return the same VMP and AMP product set.

| Method | VMP count | AMP count | Total |
| :-- | --: | --: | --: |
| SNOMED hierarchy | 2 | 25 | 27 |
| dm+d ingredient | 2 | 25 | 27 |
| SNOMED-only difference | 0 | 0 | 0 |
| dm+d-only difference | 0 | 0 | 0 |

All 27 products returned are active in dm+d.

## Local Data Used

| Source | Local version indicator |
| :-- | :-- |
| dm+d | `nhsbsa_dmd_6.0.0_20260601000001` |
| SNOMED CT | Local `SNOMEDCT` database, latest `curr_concept_f.effectivetime` observed: `20260506` |

## dm+d Ingredient Resolution

The relevant dm+d ingredient rows are:

| isid | Ingredient | Status |
| :-- | :-- | :-- |
| `108771008` | Goserelin | Active |
| `108773006` | Goserelin acetate | Active |

The two goserelin VMP ingredient rows use `108773006 |Goserelin acetate|` as the ingredient and `108771008 |Goserelin|` as `bs_subid`:

| VMP code | VMP name | Ingredient isid | Ingredient | Basis substance |
| :-- | :-- | :-- | :-- | :-- |
| `42036611000001104` | Goserelin 10.8mg implant pre-filled syringes | `108773006` | Goserelin acetate | `108771008` |
| `42036711000001108` | Goserelin 3.6mg implant pre-filled syringes | `108773006` | Goserelin acetate | `108771008` |

## Product List

| Level | Code | Product | Supplier |
| :-- | :-- | :-- | :-- |
| VMP | `42036611000001104` | Goserelin 10.8mg implant pre-filled syringes | |
| VMP | `42036711000001108` | Goserelin 3.6mg implant pre-filled syringes | |
| AMP | `16551111000001100` | Goserelin 3.6mg implant pre-filled syringes | A A H Pharmaceuticals Ltd |
| AMP | `15979611000001103` | Novgos 3.6mg implant pre-filled syringes | Genus Pharmaceuticals Ltd |
| AMP | `18155411000001109` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Mawdsley-Brooks & Company Ltd |
| AMP | `18212811000001108` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Necessity Supplies Ltd |
| AMP | `18620911000001107` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | DE Pharmaceuticals |
| AMP | `20032611000001107` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Lexon (UK) Ltd |
| AMP | `36890111000001104` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Pharmaram Ltd |
| AMP | `36918211000001100` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Abacus Medicine Ltd |
| AMP | `37393911000001108` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | CST Pharma Ltd |
| AMP | `37710311000001104` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Pilsco Ltd |
| AMP | `5258511000001105` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Waymade Healthcare Plc |
| AMP | `5326211000001104` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | Dowelhurst Ltd |
| AMP | `824211000001107` | Zoladex 3.6mg implant SafeSystem pre-filled syringes | AstraZeneca UK Ltd |
| AMP | `13992311000001100` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | DE Pharmaceuticals |
| AMP | `14736211000001106` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Sigma Pharmaceuticals Plc |
| AMP | `17481911000001104` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Mawdsley-Brooks & Company Ltd |
| AMP | `18069711000001101` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Lexon (UK) Ltd |
| AMP | `18213211000001101` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Necessity Supplies Ltd |
| AMP | `36918411000001101` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Abacus Medicine Ltd |
| AMP | `37395111000001106` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | CST Pharma Ltd |
| AMP | `37710511000001105` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Pilsco Ltd |
| AMP | `37974711000001108` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Pharmaram Ltd |
| AMP | `512511000001105` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | AstraZeneca UK Ltd |
| AMP | `5294211000001109` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Waymade Healthcare Plc |
| AMP | `5326711000001106` | Zoladex LA 10.8mg implant SafeSystem pre-filled syringes | Dowelhurst Ltd |

## Why Both Methods Match Here

The methods match for goserelin because:

- The dm+d VMP ingredient rows for goserelin are cleanly linked to the same VMP concepts that sit below the SNOMED goserelin-only product hierarchy.
- The only goserelin VMPs in the local dm+d import are single-substance goserelin products.
- Every AMP under those two VMPs is also represented as a descendant under the SNOMED goserelin-only hierarchy.
- There are no inactive goserelin VMPs or AMPs in the local dm+d result set.

## Why They Could Have Been Different

The two approaches are not equivalent in all cases.

1. Combination products

   SNOMED `776143000 |Product containing only goserelin|` means goserelin-only products. A dm+d ingredient search for "contains goserelin" would include combination products if any existed. In that case, dm+d ingredient would return more products than this SNOMED "only" hierarchy.

2. Salt and basis-substance modelling

   dm+d stores the VMP ingredient as `108773006 |Goserelin acetate|`, with `108771008 |Goserelin|` as the basis substance. A query that looked only for ingredient `108771008` and ignored `bs_subid` would miss these VMPs. Conversely, a SNOMED hierarchy may classify by the base active ingredient while dm+d records the salt as the ingredient.

3. Release timing

   dm+d and SNOMED CT UK Drug Extension are released on different cadences. A new VMP or AMP could appear in dm+d before the corresponding SNOMED hierarchy has been updated, or vice versa in a local database if one source has been refreshed and the other has not.

4. Active and inactive handling

   The SNOMED query used active SNOMED relationships and active concepts. The dm+d query can include active and inactive products depending on whether `invalid` is filtered. Historical code lists often need inactive dm+d products for lookback, which can make a dm+d-derived list larger than an active-SNOMED-only list.

5. Product level filtering

   The SNOMED descendant hierarchy can include abstract medicinal product concepts, clinical drug concepts, and real clinical drug concepts. The comparison in this report deliberately kept only concepts that also exist as dm+d VMPs or AMPs. If a query includes other levels, the SNOMED result shape may differ from a VMP/AMP-only dm+d result.

## Conclusion

For goserelin in the local data, SNOMED descendants of `776143000 |Product containing only goserelin (medicinal product)|` and dm+d ingredient resolution both produce the same VMP/AMP set: 27 active products. This is a good example where the SNOMED hierarchy and dm+d ingredient model agree, but it should not be treated as proof that they will agree for all medicines.
