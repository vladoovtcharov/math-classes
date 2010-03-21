Set Automatic Introduction.

Require Import
  RelationClasses Relation_Definitions List Morphisms
  universal_algebra abstract_algebra canonical_names
  theory.categories.
Require categories.variety.

Section contents. Variable et: EquationalTheory.

  Let op_type := op_type (sorts et).

  (* The initial object will consists of arity-0 terms with a congruence incorporating the variety's laws.
   For this we simply take universal_algebra's Term type, but exclude variables by taking False
   as the variable index type: *)

  Let ClosedTerm := (Term et False).
  Let ClosedTerm0 a := ClosedTerm (constant _ a).

  (* Operations are implemented as App-tree builders, so that [o a b] yields [App (App (Op o) a) b]. *)

  Fixpoint app_tree {o}: ClosedTerm o → op_type ClosedTerm0 o :=
    match o with
    | constant _ => id
    | function _ _ => λ x y => app_tree (App _ _ _ _ x y)
    end.

  Instance: AlgebraOps et ClosedTerm0 := λ x => app_tree (Op _ _ x).

  (* We define term equivalence on all operation types: *)

  Inductive e: Π o, Equiv (ClosedTerm o) :=
    | e_refl o: Reflexive (e o)
    | e_trans o: Transitive (e o)
    | e_sym o: Symmetric (e o)
    | e_sub o h x y a b: e _ x y → e _ a b → e _ (App _ _ h o x a) (App _ _ h o y b) 
    | e_law (s: EqEntailment et): et_laws et s → (Π (v: Vars et ClosedTerm0 nat),
      (Π x, In x (entailment_premises _ s) → e _ (eval et v (fst (projT2 x))) (eval et v (snd (projT2 x)))) →
        e _ (eval et v (fst (projT2 (entailment_conclusion _ s)))) (eval et v (snd (projT2 (entailment_conclusion _ s))))).

  Existing Instance e.
  Existing Instance e_refl.
  Existing Instance e_sym.
  Existing Instance e_trans.

  Instance: Π o, Equivalence (e o).
  Proof. constructor; apply _. Qed.

  (* .. and then take the specialization at arity 0 for Term0: *)

  Instance: Π a, Equiv (ClosedTerm0 a) := λ a => e (constant _ a).

  Instance: Π a, Setoid (ClosedTerm0 a).
  Proof. intro. unfold Setoid. apply _. Qed.

  (* While this fancy congruence is the one we'll use to make our initial object a setoid,
   in our proofs we will also need to talk about extensionally equal closed term
   builders (i.e. terms of type [op_type ClosedTerm0 a] for some a), where we use /Leibniz/ equality
   on closed terms: *)

  Let structural_eq a: relation _ := @op_type_equiv (sorts et) ClosedTerm0 (λ _ => eq) a.

  Instance structural_eq_refl a: Reflexive (structural_eq a).
  Proof. induction a; repeat intro. reflexivity. subst. apply IHa. Qed.

  (* The implementation is proper: *)

  Instance app_tree_proper: Π o, Proper (equiv ==> equiv)%signature (@app_tree o).
  Proof with auto.
   induction o; repeat intro...
   apply IHo, e_sub...
  Qed.

  Instance: Algebra et ClosedTerm0.
  Proof.
   constructor. intro. apply _.
   intro. apply app_tree_proper. reflexivity.
  Qed.
    (* hm, this isn't "the" (closed) term algebra, because we used equivalence modulo an equational theory *)


  (* Better still, the laws hold: *)

  Lemma laws_hold s (L: et_laws et s): Π vars, eval_stmt _ vars s.
  Proof with simpl in *; intuition.
   intros.
   rewrite boring_eval_entailment.
   destruct s. simpl in *. intros.
   apply (e_law _ L vars). clear L.
   induction entailment_premises... subst...
  Qed.

  (* Hence, we have a variety: *)

  Global Instance: InVariety et ClosedTerm0.
  Proof. constructor. apply _. intros. apply laws_hold. assumption. Qed.

  (* And hence, an object in the category: *)

  Definition the_object: variety.Object et := variety.object et ClosedTerm0.

  (* Interestingly, this object is initial, which we prove in the remainder of this file. *)

  (* To show its initiality, we begin by constructing arrows to arbitrary other objects: *)

  Section for_another_object. Variable other: variety.Object et.

    (* Computationally, the arrow simply evaluates closed terms in the other
     model. For induction purposes, we first define this for arbitrary op_types: *)

    Definition eval_in_other {o}: ClosedTerm o → op_type other o := @eval et other _ False o (no_vars _ other).

    Definition morph a: the_object a → other a := eval_in_other.

    (* Given an assignment mapping variables to closed terms of arity 0, we can now
     evaluate open terms in the other model in two ways: by first closing it and then
     evaluating the closed term using eval_in_other, or by evaluating it directly but
     with variable lookup implemented in terms of eval_in_other. We now show that
     these two ways yield the same result, thanks to proper-ness of the algebra's
     operations: *)

    Lemma subst_eval o V (v: Vars _ ClosedTerm0 _) (t: Term _ V o):
      @eval _ other _ _ _ (λ x y => eval_in_other (v x y)) t =
      eval_in_other (close _ v t).
    Proof.
     induction t; simpl.
       reflexivity.
      apply IHt1. auto.
     apply (@algebra_propers et other _ _ _ o).
    Qed. (* todo: rename *)

    (* On the side of the_object, evaluating a term of arity 0 is the same as closing it: *)

    Lemma eval_is_close V x v (t: Term0 et V x): eval et v t ≡ close _ v t.
    Proof with auto; try reflexivity.
     pattern x, t.
     apply applications_ind; simpl...
     intro.
     cut (@equiv _ (structural_eq _) (app_tree (close _ v (Op et _ o))) (eval et v (Op et _ o)))...
     generalize (Op et V o).
     induction (et o); simpl...
     intros ? H ? E. apply IHo0. simpl. rewrite E. apply H...
    Qed.

    (* And with those two somewhat subtle lemmas, we show that eval_in_other is a setoid morphism: *)

    Instance prep_proper: Proper (equiv ==> equiv) (@eval_in_other o).
    Proof with intuition.
     intros o x y H.
     induction H; simpl...
        induction x; simpl...
         apply IHx1...
        apply (@algebra_propers et other _ _ _ o).
       transitivity (eval_in_other y)...
      apply IHe1...
     unfold Vars in v.
     pose proof (@variety_laws et other _ _ _ s H (λ a n => eval_in_other (v a n))) as Q.
     clear H.
     destruct s.
     rewrite boring_eval_entailment in Q.
     simpl in *.
     do 2 rewrite eval_is_close.
     do 2 rewrite <- subst_eval.
     apply Q. clear Q.
     induction entailment_premises; simpl...
     do 2 rewrite subst_eval.
     do 2 rewrite <- eval_is_close...
    Qed.

    Instance: Π a, Setoid_Morphism (@eval_in_other (constant _ a)).
    Proof. constructor; simpl; try apply _. Qed.

    (* Furthermore, we can show preservation of operations, giving us a homomorphism (and an arrow): *)

    Instance: @HomoMorphism et ClosedTerm0 other _ (variety.variety_equiv et other) _ _ (λ _ => eval_in_other).
    Proof with intuition.
     constructor; try apply _.
     intro.
     change (Preservation et ClosedTerm0 other (λ _ => eval_in_other) (app_tree (Op _ _ o)) (variety.variety_op _ other o)).
     generalize (algebra_propers et o  : eval_in_other (Op _ _ o) = variety.variety_op _ other o).
     generalize (Op _ False o) (variety.variety_op et other o).
     induction (et o)...
     simpl. intro. apply IHo0, H.
     apply reflexivity. (* todo: shouldn't have to say [apply] here. file bug *)
    Qed.

    Program Definition the_arrow: the_object ⟶ other := λ _ => eval_in_other.

    (* All that remains is to show that this arrow is unique: *)

    Theorem arrow_unique: Π y, the_arrow = y.
    Proof with auto; try intuition.
     intros [x h] b a.
     simpl in *.
     pattern b, a.
     apply applications_ind...
     intros.
     pose proof (@preserves et ClosedTerm0 other _ _ _ _ x h o).
     change (Preservation et ClosedTerm0 other x (app_tree (Op _ _ o)) (@eval_in_other _ (Op _ _ o))) in H.
     revert H.
     generalize (Op _ False o).
     induction (et o); simpl...
     intros.
     apply IHo0.
     simpl in *.
     assert (app_tree (App _ _ o0 a0 t v) = app_tree (App _ _ o0 a0 t v)).
      apply app_tree_proper...
     apply (@Preservation_proper et ClosedTerm0 other _ _ x _ _ _ o0
      (app_tree (App _ _ o0 a0 t v)) (app_tree (App _ _ o0 a0 t v)) H1
      (eval_in_other t (eval_in_other v)) (eval_in_other t (x a0 v)))...
     pose proof (@prep_proper _ t t (reflexivity _))... (* todo: why doesn't rewrite work here? *)
    Qed. (* todo: needs further cleanup *)

  End for_another_object.

  Hint Extern 4 (InitialArrow the_object) => exact the_arrow: typeclass_instances.

  Instance: Initial the_object.
  Proof. intro. apply arrow_unique. Qed.

  (* Todo: Show decidability of equality (likely quite tricky). Without that, we cannot use any of this to
   get a canonical model of the naturals/integers, because such models must be decidable. *)

End contents.
