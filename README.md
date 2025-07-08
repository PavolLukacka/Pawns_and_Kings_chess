# Pawns and Kings Chess

„Pawns and Kings Chess“ je zjednodušená šachová simulácia postavená v prostredí NetLogo. Projekt demonštruje princípy herného stromového vyhľadávania (Minimax) a jeho optimalizácie (α-β orezávanie) na variant šachu s len jedným kráľom a ôsmimi pešiakmi na každej strane.

---

## Obsah

- [Funkcie](#funkcie)  
- [Požiadavky](#požiadavky)  
- [Inštalácia](#inštalácia)  
- [Použitie](#použitie)  
- [Architektúra](#architektúra)  
- [Algoritmy](#algoritmy)  
- [Hodnotiaca funkcia](#hodnotiaca-funkcia)  
- [Testovanie a experimenty](#testovanie-a-experimenty)  
- [Možné rozšírenia](#možné-rozšírenia)  
- [Autor](#autor)  
- [Licencia](#licencia)  

---

## Funkcie

- **Zjednodušené pravidlá**: Každá strana len 1 kráľ + 8 pešiakov, bez promócie a en passant.  
- **Minimax + α-β orezávanie**: Hľadanie optimálneho ťahu do nastavenej hĺbky.  
- **Undo/redo ťahov**: Simulácia ťahov so zásobníkom pre vrátenie stavu.  
- **Detekcia opakovaných pozícií**: Jedinečné „kľúče“ pozícií a tabuľka na sledovanie repetičných stavov.  
- **Interaktívne rozhranie**: Tlačidlá `Setup`, `Step`, `Run whole game` a monitorovacie grafy (evaluation, material diff, nodes/ply, king distance).

---

## Požiadavky

- [NetLogo](https://ccl.northwestern.edu/netlogo/) (verzia 6.x alebo vyššia)  
- JVM (java) – ak NetLogo využíva externý Java runtime  

---

