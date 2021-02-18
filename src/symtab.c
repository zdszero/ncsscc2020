#include "symtab.h"
#include <string.h>
#include <stdlib.h>

SymRec SymTab[NSYMBOLS];

static int Symbols = 0;
static int isFirstTime = 1;

int pointerTo(int type) {
  int newtype;
  switch (type) {
    case T_Void:
      newtype = T_Voidptr;
      break;
    case T_Char:
      newtype = T_Charptr;
      break;
    case T_Int:
      newtype = T_Intptr;
      break;
    case T_Long:
      newtype = T_Longptr;
      break;
    default:
      fprintf(stderr, "Unrecognized type %d to point to in line %d\n", type, lineno);
      exit(1);
  }
  return newtype;
}

int valueAt(int type) {
  int newtype;
  switch (type) {
    case T_Voidptr:
      newtype = T_Void;
      break;
    case T_Charptr:
      newtype = T_Char;
      break;
    case T_Intptr:
      newtype = T_Int;
      break;
    case T_Longptr:
      newtype = T_Long;
      break;
    default:
      fprintf(stderr, "Unrecognized type to dereference\n");
      exit(1);
  }
  return newtype;
}

int newIdent(char *s, int kind, int type) {
  if (isFirstTime) {
    SymTab[0].name = "printchar";
    SymTab[0].type = T_Void;
    SymTab[0].kind = Sym_Func;
    SymTab[1].name = "printint";
    SymTab[1].type = T_Void;
    SymTab[1].kind = Sym_Func;
    SymTab[2].name = "printlong";
    SymTab[2].type = T_Void;
    SymTab[2].kind = Sym_Func;
    isFirstTime = 0;
    Symbols = 3;
  }
  SymTab[Symbols].name = strdup(s);
  SymTab[Symbols].kind = kind;
  SymTab[Symbols].type = type;
  SymTab[Symbols].arr = NULL;
  return Symbols++;
}

void setIdentType(int id, int type) {
  SymTab[id].type = type;
}

void setIdentKind(int id, int kind) {
  SymTab[id].kind = kind;
}

/* find identifier in symbol table and return its index */
int getIdentId(char *s) {
  int i;
  for (i = 0; i < Symbols && SymTab[i].name != NULL; i++) {
    if (strcmp(s, SymTab[i].name) == 0)
      return i;
  }
  return -1;
}

char *getIdentName(int id) {
  return SymTab[id].name;
}

int getIdentType(int id) {
  return SymTab[id].type;
}

int getIdentKind(int id) {
  return SymTab[id].kind;
}

int getArrayDimension(int id, int d) {
  DimRec *tmp = SymTab[id].arr->first;
  for (int i = 1; i < d; i++)
    tmp = tmp->next;
  return tmp->dim;
}

int getArrayTotal(int id, int level) {
  DimRec *tmp = SymTab[id].arr->first;
  for (int i = 1; i < level; i++)
    tmp = tmp->next;
  int ans = 1;
  while (tmp) {
    ans *= tmp->dim;
    tmp = tmp->next;
  }
  return ans;
}

int getArrayDims(int id) {
  return SymTab[id].arr->dims;
}

void setArrayDimension(int id, int d, int val) {
  DimRec *tmp = SymTab[id].arr->first;
  for (int i = 1; i < d; i++)
    tmp = tmp->next;
  tmp->dim = val;
}

void printDimension(int id) {
  DimRec *tmp = SymTab[id].arr->first;
  fprintf(Outfile, "(");
  while (tmp) {
    fprintf(Outfile, "%d,", tmp->dim);
    tmp = tmp->next;
  }
  fprintf(Outfile, ")");
}

void setDimension(int id, int level, int val) {
  DimRec *tmp = SymTab[id].arr->first;
  for (int i = 1; i < level; i++)
    tmp = tmp->next;
  tmp->dim = val;
}

void addDimension(int id, int d) {
  DimRec *dr = (DimRec *) malloc(sizeof(DimRec));
  dr->dim = d;
  dr->next = NULL;
  if (!SymTab[id].arr) {
    SymTab[id].arr = (ArrayRec *) malloc(sizeof(ArrayRec));
    SymTab[id].arr->dims = 0;
  }
  DimRec *tmp = SymTab[id].arr->first;
  SymTab[id].arr->dims++;
  if (!tmp)
    SymTab[id].arr->first = dr;
  else {
    while (tmp->next)
      tmp = tmp->next;
    tmp->next = dr;
  }
}
