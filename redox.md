# Summary

In the stoichiometry mode, the reactants should not be assumed as an element, but can be a compound.
It means left or right dropzone in the stoichometry mode, can accept multiple elements, selected by user from periodic table. The rule on what compound will be formed follow the existing bonding rules. The calculation of compound in each dropzone, if at least 2 elements are droped in to the drop zone. 

A new calculator should be created, to calculate the oxidation states, before and after the reaction then determine whether the reaction redox or non-redox. This should be called by the stochiometry calcultor to include the type of the reaction, if it is `redox or non redox`, what is the `oxidizing agent`, `reducing agent`. The following is the template for redox analysis,
```text
[Substance/Element] is [oxidised | reduced] because its oxidation state [increases | decreases] from [Initial State, e.g., +2] in [Reactant Formula] to [Final State, e.g., 0] in [Product Formula].
```
example,

`Acidified potassium manganate(VII) is the oxidising agent because it oxidises iron(II) ions and itself undergoes reduction where its oxidation state decreases from +7 to +2.`