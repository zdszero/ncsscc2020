#include "symtab.h"
#include "analyze.h"
#include <stdlib.h>

static int isPointerType(int type) {
  return (type >= T_Voidptr && type <= T_Longptr);
}

static int isNumberType(int type) {
  return (type == T_Int || type == T_Long);
}

static int getScaleSize(int type) {
  if (type == T_Intptr)
    return 4;
  else if (type == T_Longptr)
    return 8;
  return 1;
}

static int isComparable(int t1, int t2) {
  if (t1 == T_Void || t2 == T_Void)
    return 0;
  return 1;
}

/* return true if the last sibling is return type */
static int hasReturn(TreeNode *t) {
  while (t->sibling)
    t = t->sibling;
  if (t->tok == RETURN)
    return 1;
  return 0;
}

/* check type when assigning */
void typeCheck_Assign(TreeNode *t1, TreeNode *t2) {
  if (!isComparable(t1->type, t2->type)) {
    fprintf(stderr, "Error: assign between two types that are not compatible at line %d\n", lineno);
    exit(1);
  }
}

void typeCheck_Compare(TreeNode *t1, TreeNode *t2) {
  if (!isComparable(t1->type, t2->type)) {
    fprintf(stderr, "Error: wrong types for comparison at line %d", lineno);
    exit(1);
  }
}

void typeCheck_Calc(TreeNode *t1, TreeNode *t2) {
  if (!isComparable(t1->type, t2->type)) {
    fprintf(stderr, "Error: wrong types for arithmetic calculation at line %d", lineno);
    exit(1);
  } else if (isPointerType(t1->type) && isNumberType(t2->type)) {
    t2->attr.val *= getScaleSize(t1->type);
  } else if (isNumberType(t1->type) && isPointerType(t2->type)) {
    t1->attr.val *= getScaleSize(t2->type);
  }
}

void typeCheck_HasReturn(TreeNode *t1, TreeNode *t2, int id) {
  if (t1->type == T_Void && hasReturn(t2)) {
    fprintf(stderr, "Error: return statment in void function %s\n", getIdentName(id));
    exit(1);
  } else if (t1->type != T_Void && !hasReturn(t2)) {
    fprintf(stderr, "Error: missing return statement in function %s\n", getIdentName(id));
    exit(1);
  }
}

/* guess the first dimension of array */
void checkArray(TreeNode *t) {
  int id = t->attr.id;
  int d1 = getArrayDimension(id, 1);
  if (d1 != 0)
    return;
  if ((!t->children[0] || !t->children[0]->children[0]) && (d1 == 0)) {
    fprintf(stderr, "Error: array size cannot be gussed in line %d\n", lineno);
    exit(1);
  }
  d1 = 0;
  int dims = getArrayDims(id);
  for (TreeNode *tmp = t->children[0]->children[0]; tmp; tmp = tmp->sibling) {
    while (tmp && tmp->tok == NUM) {
      if (dims == 1)
        d1++;
      tmp = tmp->sibling;
    }
    if (!tmp)
      break;
    d1++;
  }
  setArrayDimension(id, 1, d1);
}
