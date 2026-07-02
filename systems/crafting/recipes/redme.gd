'1. Criar um Ingrediente (O que é necessário)
Para cada item necessário em uma receita, você precisa de um recurso de "Ingrediente".

No painel de FileSystem, vá para a pasta res://crafting/recipes/.
Clique com o botão direito -> New -> Resource.
Procure por RecipeIngredient e clique em Create.
Dê um nome (ex: ingrediente_madeira_5.tres).
No Inspector:
Item: Arraste o item que será usado (ex: madeira.tres).
Count: Coloque a quantidade necessária (ex: 5).
2. Criar a Receita (O produto final)
Agora você une os ingredientes ao item que será criado.

Clique com o botão direito na pasta de receitas -> New -> Resource.
Procure por CraftingRecipe e clique em Create.
Dê um nome (ex: receita_baú.tres).
No Inspector:
Display Name: Nome que aparecerá na lista (ex: "Baú de Carvalho").
Ingredients: Clique em "Add Element" e arraste os recursos de Ingrediente que você criou no Passo 1.
Result Item: Arraste o item que o jogador vai ganhar (ex: bau_item.tres).
Result Count: Quantidade que será criada (geralmente 1).
3. Adicionar ao Painel de Crafting
Para que a receita apareça no jogo, você precisa registrá-la no painel:

Abra a cena res://crafting/ui/crafting_panel.tscn.
Selecione o nó raiz CraftingPanel.
No Inspector, procure a propriedade Recipes (é um Array).
Clique em "Add Element" no Array.
Arraste a sua nova Receita (criada no Passo 2) para dentro do novo slot.
Dica Pro: Sub-recursos (Mais rápido)
Você não precisa criar arquivos .tres separados para cada ingrediente se não quiser.

Dentro da sua Receita, na lista de Ingredients, você pode clicar em "Empty" -> New RecipeIngredient diretamente. Assim o ingrediente fica "salvo" dentro da própria receita, economizando arquivos na pasta!'
