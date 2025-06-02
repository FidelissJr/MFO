module rpg {
    type Option[a] =
    | Some(a)
    | None

    pure def count(conjunto: Set[a]): int = conjunto.fold(0, (acc, i) => acc + 1)

    type TipoCriatura = Sacerdote | Bardo | Necromante | Inimigo

    type Efeito = Cura | Canto | Lanca

    type Criatura = {
        hp: int,
        classe: TipoCriatura,
        paralisia: bool,
        efeito: Option[Efeito],
        iniciativa: int,
        ritual: Option[str]
    }

    var criaturas: List[Criatura]
    var criatura: int
    var turno: int
    var info_turno: Option[{ jogador: Criatura, vitima: Option[Criatura], acao_tomada: str, dano: Option[int] }]

    pure def paralisar(c: Criatura, p: bool): Criatura = { ...c, paralisia: p }

    pure def ordena_criaturas(criaturas: List[Criatura]): List[Criatura] =
        criaturas.foldl([], (acc, criatura) => 
            val antes = acc.select(c => criatura.iniciativa < c.iniciativa)
            val depois = acc.select(c => criatura.iniciativa >= c.iniciativa)
            antes.append(criatura).concat(depois)
        )
    
    pure def aplicar_dano(c: Criatura, dano: int): Criatura = {
        if (c.hp - dano <= 0) { ...c, hp: 0 }
        else { ...c, hp: c.hp - dano } 
    }

    pure def aumentar_hp(criaturas: List[Criatura]): List[Criatura] =
        criaturas.foldl([], (acc, criatura) =>
            if (criatura.classe != Inimigo and criatura.hp > 0){
                val hp_ajustado = if(criatura.hp > 10) 20 else criatura.hp + 10
                acc.append({ ...criatura, hp: hp_ajustado })
            }
            else {
                acc.append(criatura)
            }
        )

    pure def matar_todos_personagens(criaturas: List[Criatura]): List[Criatura] =
        criaturas.foldl([], (acc, criatura) =>
            if (criatura.classe != Inimigo and criatura.hp > 0){
                acc.append({ ...criatura, hp: 0 })
            }
            else {
                acc.append(criatura)
            }
        )

    pure def existe_personagens_com_pouco_hp(criaturas: List[Criatura]): bool =
        criaturas.indices().exists(x => criaturas[x].classe != Inimigo and criaturas[x].hp <= 10)

    pure def existe_inimigo_com_ritual_iniciado(criaturas: List[Criatura]): bool =
        criaturas.indices().exists(x => criaturas[x].classe == Inimigo and criaturas[x].ritual != None)

    action paralisar_personagem(inimigo: Criatura, pos_personagem: int): bool = {
        val personagem = criaturas[pos_personagem]
        all {
            personagem.hp > 0,
            not(personagem.paralisia),
            inimigo.classe == Inimigo,
            personagem.classe != Inimigo,
            criaturas' = criaturas.replaceAt(pos_personagem, personagem.paralisar(true)).replaceAt(criatura, { ...inimigo, efeito: None }),
            info_turno' = Some({ jogador: inimigo, vitima: Some(personagem), acao_tomada: "paralisar_personagem", dano: None })
        }
    }

    action remover_paralisia(personagem: Criatura, pos_personagem_paralisado: int): bool = {
        val personagem_paralisado = criaturas[pos_personagem_paralisado]
        all {
            personagem_paralisado.hp > 0,
            personagem_paralisado.paralisia,
            personagem_paralisado.classe != Inimigo,
            personagem.classe != Inimigo,
            personagem != personagem_paralisado,
            criaturas' = criaturas.replaceAt(pos_personagem_paralisado, personagem_paralisado.paralisar(false)).replaceAt(criatura, { ...personagem, efeito: None }),
            info_turno' = Some({ jogador: personagem, vitima: Some(personagem_paralisado), acao_tomada: "remover_paralisia", dano: None })
        }
    }

    action cura_sacerdote(personagem: Criatura): bool = {
        all {
            personagem.hp > 0,
            personagem.classe == Sacerdote,
            not(personagem.paralisia),
            criaturas' = aumentar_hp(criaturas),
            info_turno' = Some({ jogador: personagem, vitima: None, acao_tomada: "Cura sacerdote", dano: None })
        }
    }

    action canto_bardo(personagem: Criatura): bool = {
        all {
            personagem.hp > 0,
            personagem.classe == Bardo,
            not(personagem.paralisia),
            criaturas' = criaturas.replaceAt(criatura, { ...personagem, efeito: Some(Canto) }),
            info_turno' = Some({ jogador: personagem, vitima: None, acao_tomada: "Canto bardo", dano: None })
        }
    }

    action lanca_de_sangue(agressor: Criatura): bool = {
        nondet pos_vitima = criaturas.indices().filter(x => criaturas[x].classe == Inimigo).oneOf()

        val vitima = criaturas[pos_vitima]

        val bardo = criaturas.select(x => x.classe == Bardo).head()

        val dano = match bardo.efeito {
            | Some(e) => 20 * 3
            | None => 20
        }

         nondet pos_bardo = criaturas.indices().filter(i => criaturas[i].classe == Bardo).oneOf()

        all {
            vitima.hp > 0,
            not(agressor.paralisia),
            agressor != vitima,
            criaturas' = criaturas.replaceAt(pos_vitima, aplicar_dano(vitima, dano)).replaceAt(pos_bardo, { ...criaturas[pos_bardo], efeito: None }).replaceAt(criatura, { ...agressor, hp: agressor.hp - 10 }),
            info_turno' = Some({ jogador: agressor, vitima: Some(vitima), acao_tomada: "lanca de sangue", dano: Some(dano) })
        }
    }

    action ataque(agressor: Criatura): bool = {
        nondet pos_vitima = criaturas.indices().filter(x => x != criatura and if (agressor.classe == Inimigo) criaturas[x].classe != Inimigo else criaturas[x].classe == Inimigo).oneOf()

        val vitima = criaturas[pos_vitima]

        val bardo = criaturas.select(x => x.classe == Bardo).head()

        val dano = match bardo.efeito {
            | Some(e) => 10 * 3
            | None => 10
        }

        nondet pos_bardo = criaturas.indices().filter(i => criaturas[i].classe == Bardo).oneOf()

        all {
            vitima.hp > 0,
            not(agressor.paralisia),
            agressor != vitima,
            criaturas' = criaturas.replaceAt(pos_bardo, { ...criaturas[pos_bardo], efeito: None }).replaceAt(pos_vitima, aplicar_dano(vitima, dano)),
            info_turno' = Some({ jogador: agressor, vitima: Some(vitima), acao_tomada: "ataque", dano: Some(dano) })
        }
    }

    action iniciar_ritual(inimigo: Criatura): bool = {
        all {
            inimigo.hp > 0,
            inimigo.classe == Inimigo,
            inimigo.ritual == None,
            not(inimigo.paralisia),
            criaturas' = criaturas.replaceAt(criatura, { ...inimigo, ritual: Some("Ritual iniciado") }),
            info_turno' = Some({ jogador: inimigo, vitima: None, acao_tomada: "iniciar_ritual", dano: None })
        }
    }

    action finalizar_ritual(inimigo: Criatura): bool = {
        all {
            inimigo.hp > 0,
            inimigo.classe == Inimigo,
            not(inimigo.ritual == None),
            not(inimigo.paralisia),
            criaturas' = criaturas.replaceAt(criatura, { ...inimigo, ritual: Some("Finalizar ritual") }).matar_todos_personagens(),
            info_turno' = Some({ jogador: inimigo, vitima: None, acao_tomada: "finalizar_ritual", dano: None })
        }
    }

    
    action init = {
        val dado = 1.to(20)
        nondet ini_sacerdote = dado.oneOf()
        nondet ini_bardo = dado.oneOf()
        nondet ini_necromante = dado.oneOf()
        nondet ini_inimigo = dado.oneOf()
        nondet ini_inimigo_2 = dado.oneOf()

        all{
                criaturas' = ordena_criaturas(
                [
                    { hp: 20, classe: Sacerdote, paralisia: false, efeito: None, iniciativa: ini_sacerdote, ritual: None },
                    { hp: 20, classe: Bardo, paralisia: false, efeito: None, iniciativa: ini_bardo, ritual: None},
                    { hp: 20, classe: Necromante, paralisia: false, efeito: None, iniciativa: ini_necromante, ritual: None},
                    { hp: 70, classe: Inimigo, paralisia: false, efeito: None, iniciativa: ini_inimigo, ritual: None},
                    { hp: 70, classe: Inimigo, paralisia: false, efeito: None, iniciativa: ini_inimigo_2, ritual: None}
                ]),

            criatura' = 0,
            turno' = 1,
            info_turno' = None
        }
    }

    action step = {
    val jogador = criaturas[criatura]
    val proximo = if (criatura + 1 == criaturas.length()) 0 else criatura + 1
    val antes = if (criatura - 1 == -1) criaturas.length() - 1 else criatura - 1
    nondet possivel_vitima = criaturas.indices().oneOf()
    
    all {
            jogador.hp > 0,
            not(jogador.paralisia),

            if(jogador.classe == Inimigo)
            {
                if(turno == 1 and not(existe_inimigo_com_ritual_iniciado(criaturas))) jogador.iniciar_ritual() 
                else if (turno == 4 and jogador.ritual != None) jogador.finalizar_ritual() 
                else 
                { 
                    any {
                        jogador.ataque(), 
                        paralisar_personagem(jogador, possivel_vitima)                     
                    }
                }
            }

            else if (criaturas.select(x => x.paralisia).length() > 0) remover_paralisia(jogador, possivel_vitima)
            else if (jogador.classe == Sacerdote and existe_personagens_com_pouco_hp(criaturas)) jogador.cura_sacerdote()
            else if (jogador.classe == Bardo and criaturas[proximo].classe == Necromante) jogador.canto_bardo()
            else if (jogador.classe == Necromante and jogador.hp > 10 and criaturas[proximo].classe == Sacerdote) jogador.lanca_de_sangue()
            else jogador.ataque(),

            criatura' = if (criatura + 1 == criaturas.length()) 0 else criatura + 1,
            turno' = if (criatura + 1 == criaturas.length()) turno + 1 else turno,
        }
    }

    val inimigo_nao_morre = criaturas.indices().filter(i => criaturas[i].classe == Inimigo).forall(i => criaturas[i].hp > 0)
    val personagens_nao_morrem = criaturas.indices().filter(i => criaturas[i].classe != Inimigo).forall(x => criaturas[x].hp > 0)

}