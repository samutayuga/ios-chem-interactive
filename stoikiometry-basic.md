# Summary

The stoikiometry calculator give the `quantity` of the product from a chemical reaction in terms of moles or mass.
It uses the basic understanding of chemistrystoichiometry, such as limiting reactant, excess reactant, and the concept of mole, based on the the law of mass conservation. For a given chemical reaction with known quantities of reactants, the calculator will output the theoretical yield of the products, the mass of any excess reactants remaining after the reaction, and the identity of the limiting reactant.
The user should be able to input the quantity of substance or element, which can be in the form of moles or mass, depending on the user selection on the unit from dropdown. The input fields should be part of the first reactant, once the user drop/tap the element, then on the dropsone two input fields should appear, 1. quantity is a floating number, and 2. a unit selection (mole or mass).
The output should be in the form of text with element or substance and its quantity in moles or mass.
If the user doesn't input any quantity, it should be assumed that the reactants are in stoichiometric amounts.

The calculator should be part of the Chemcore Library.

# Calculation Steps

1.  **Balancing the chemical equation**: The calculator must first balance the chemical equation to ensure that the law of mass conservation is satisfied. This can be done using the least common multiple method or by solving a system of linear equations.
2.  **Calculating moles of reactants**: The calculator must then calculate the moles of each reactant using the given quantities and their molar masses. The molar mass of each element can be obtained from the periodic table, and the molar mass of each compound can be calculated by summing the molar masses of its constituent elements.
3.  **Identifying the limiting reactant**: The limiting reactant is the reactant that is completely consumed in the reaction and thus limits the amount of product that can be formed. It can be identified by comparing the mole ratios of the reactants to the stoichiometric coefficients in the balanced chemical equation.
4.  **Calculating theoretical yield**: The theoretical yield is the maximum amount of product that can be formed from the given quantities of reactants. It can be calculated by using the mole ratios of the reactants to the products in the balanced chemical equation.
5.  **Calculating excess reactant**: The excess reactant is the reactant that is not completely consumed in the reaction and thus remains after the reaction. It can be identified by comparing the mole ratios of the reactants to the stoichiometric coefficients in the balanced chemical equation.
6.  **Calculating mass of excess reactant**: The mass of the excess reactant can be calculated by multiplying the moles of the excess reactant by its molar mass.

# Formula

The following formulas should be used to calculate the theoretical yield and excess reactant:

```
moles_of_reactant = mass_of_reactant / molar_mass_of_reactant

theoretical_yield = (moles_of_reactant * stoichiometric_coefficient_of_product) / stoichiometric_coefficient_of_reactant

mass_of_excess_reactant = moles_of_excess_reactant * molar_mass_of_excess_reactant
```

# Input validation

The calculator should validate the following inputs:

1. The chemical equation should be valid and balanced.
2. The quantities of the reactants should be positive numbers.
3. The molar masses of the reactants and products should be positive numbers.

# Output

The calculator should output the following values:

1. The theoretical yield of the product in moles and mass.
2. The identity of the limiting reactant.
3. The mass of excess reactant remaining after the reaction.
