/*
 * Copyright (C) 2010, 2011, 2012, 2013, 2014 Mail.RU
 * Copyright (C) 2010, 2011, 2012, 2013, 2014 Yuriy Vostrikov
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#import <util.h>
#import <say.h>
#import <tbuf.h>
#import <fiber.h>
#import <pickle.h>
#import <index.h>

#include <stdbool.h>

#import <mod/box/box.h>
#import <cfg/octopus.h>

static struct index_node *
box_tuple_u32_dtor(struct tnt_object *obj, struct index_node *node, void *arg)
{
	int n = (uintptr_t)arg;
	struct box_tuple *tuple = box_tuple(obj);
	if (tuple->cardinality <= n)
		index_raise("cardinality too small");
	u8 *f = tuple_field(tuple, n);
	u32 size = LOAD_VARINT32(f);
	if (size != sizeof(u32))
		index_raise("expected u32");

	node->obj = obj;
	node->key.u32 = *(u32*)f;
	return node;
}
static struct index_node *
box_tuple_u64_dtor(struct tnt_object *obj, struct index_node *node, void *arg)
{
	int n = (uintptr_t)arg;
	struct box_tuple *tuple = box_tuple(obj);
	if (tuple->cardinality <= n)
		index_raise("cardinality too small");
	const u8 *f = tuple_field(tuple, n);
	u32 size = LOAD_VARINT32(f);
	if (size != sizeof(u64))
		index_raise("expected u64");

	node->obj = obj;
	node->key.u64 = *(u64*)f;
	return node;
}
static struct index_node *
box_tuple_i32_dtor(struct tnt_object *obj, struct index_node *node, void *arg)
{
	int n = (uintptr_t)arg;
	struct box_tuple *tuple = box_tuple(obj);
	if (tuple->cardinality <= n)
		index_raise("cardinality too small");
	u8 *f = tuple_field(tuple, n);
	u32 size = LOAD_VARINT32(f);
	if (size != sizeof(u32))
		index_raise("expected i32");

	node->obj = obj;
	node->key.u32 = *(u32*)f - INT32_MIN;
	return node;
}
static struct index_node *
box_tuple_i64_dtor(struct tnt_object *obj, struct index_node *node, void *arg)
{
	int n = (uintptr_t)arg;
	struct box_tuple *tuple = box_tuple(obj);
	if (tuple->cardinality <= n)
		index_raise("cardinality too small");
	const u8 *f = tuple_field(tuple, n);
	u32 size = LOAD_VARINT32(f);
	if (size != sizeof(u64))
		index_raise("expected i64");

	node->obj = obj;
	node->key.u64 = *(u64*)f - INT64_MIN;
	return node;
}
static struct index_node *
box_tuple_lstr_dtor(struct tnt_object *obj, struct index_node *node, void  *arg)
{
	int n = (uintptr_t)arg;
	struct box_tuple *tuple = box_tuple(obj);
	if (tuple->cardinality <= n)
		index_raise("cardinality too small");
	void *f = tuple_field(tuple, n);
	node->obj = obj;
	memcpy(&node->key, &f, sizeof(void *));
	return node;
}
static struct index_node *
box_tuple_gen_dtor(struct tnt_object *obj, struct index_node *node, void *arg)
{
	struct index_conf *desc = arg;
	struct box_tuple *tuple = box_tuple(obj);
	const u8 *tuple_data = tuple->data;

	if (tuple->cardinality < desc->min_tuple_cardinality)
		index_raise("tuple cardinality too small");

	for (int i = 0, j = 0; i < desc->cardinality; j++) {
		assert(tuple_data < (const u8 *)tuple->data + tuple->bsize);
		u32 len = LOAD_VARINT32(tuple_data);
		for (;;) {
			int indi = desc->fill_order[i];
			if (desc->field_index[indi] != j) break;
			union index_field *f = (void *)&node->key + desc->offset[indi];
			gen_set_field(f, desc->field_type[indi], len, tuple_data);
			i++;
		}
		tuple_data += len;
	}

	node->obj = obj;
	return (struct index_node *)node;
}

struct dtor_conf box_tuple_dtor = {
	.i32 = box_tuple_i32_dtor,
	.i64 = box_tuple_i64_dtor,
	.u32 = box_tuple_u32_dtor,
	.u64 = box_tuple_u64_dtor,
	.lstr = box_tuple_lstr_dtor,
	.generic = box_tuple_gen_dtor
};

typedef struct {
	int type;
	char** name;
} typenames;

#define eq(t, s) (strcmp((t),(s)) == 0)
static typenames *one_column_types = (typenames[]){
	{SNUM32, (char *[]){"NUM", "SNUM", "NUM32", "SNUM32", NULL}},
	{SNUM64, (char *[]){"NUM64", "SNUM64", NULL}},
	{STRING, (char *[]){"STR", "STRING", NULL}},
	{UNUM32, (char *[]){"UNUM", "UNUM32", NULL}},
	{UNUM64, (char *[]){"UNUM64", NULL}},
	{SNUM16, (char *[]){"NUM16", "SNUM16", NULL}},
	{UNUM16, (char *[]){"UNUM16", NULL}},
	{UNDEF, (char *[]){NULL}}
};

static typenames *many_column_types = (typenames[]){
	{UNUM32, (char *[]){"NUM", "UNUM", "NUM32", "UNUM32", NULL}},
	{UNUM64, (char *[]){"NUM64", "UNUM64", NULL}},
	{STRING, (char *[]){"STR", "STRING", NULL}},
	{SNUM32, (char *[]){"SNUM", "SNUM32", NULL}},
	{SNUM64, (char *[]){"SNUM64", NULL}},
	{UNUM16, (char *[]){"NUM16", "UNUM16", NULL}},
	{SNUM16, (char *[]){"SNUM16", NULL}},
	{UNDEF, (char *[]){NULL}},
};


struct index_conf *
cfg_box2index_conf(struct octopus_cfg_object_space_index *c)
{
	struct index_conf *d = xcalloc(1, sizeof(*d));

	for (int i = 0; i < nelem(d->field_index); i++)
		d->field_index[i] = d->fill_order[i] = d->offset[i] = -1;

	d->unique = c->unique;
	if (strcmp(c->type, "HASH") == 0)
		d->type = HASH;
	else if (strcmp(c->type, "NUMHASH") == 0)
		d->type = NUMHASH;
	else if (strcmp(c->type, "TREE") == 0)
		d->type = COMPACTTREE;
	else if (strcmp(c->type, "FASTTREE") == 0)
		d->type = FASTTREE;
	else if (strcmp(c->type, "SPTREE") == 0)
		d->type = SPTREE;
	else
		panic("unknown index type");

	__typeof__(c->key_field[0]) key_field;
	for (d->cardinality = 0; c->key_field[d->cardinality] != NULL; d->cardinality++) {
		key_field = c->key_field[d->cardinality];
		if (key_field->fieldno == -1)
			panic("fieldno should be set");

		if (!eq(key_field->sort_order, "ASC") && !eq(key_field->sort_order, "DESC"))
			panic("unknown sort order");
	}

	if (d->cardinality > nelem(d->field_index))
		panic("index cardinality is too big");

	if (d->cardinality == 0)
		panic("index cardinality is 0");

	int offset = 0;
	for (int k = 0; k < d->cardinality; k++) {
		key_field = c->key_field[k];
		d->fill_order[k] = k;
		d->field_index[k] = key_field->fieldno;
		d->offset[k] = offset;
		d->sort_order[k] = eq(key_field->sort_order, "ASC") ? ASC : DESC;

		const char *typename = key_field->type;
		int type = UNDEF;
		typenames *names = d->cardinality == 1 ? one_column_types : many_column_types;
		for (;type == UNDEF && names->type != UNDEF; names++) {
			char **name = names->name;
			for(;*name != NULL; name++) {
				if (eq(typename, *name)) {
					type = names->type;
					break;
				}
			}
		}
		if (type == UNDEF) {
			panic("unknown field data type: `%s'", typename);
		}
		d->field_type[k] = type;
		switch(type & ~SIGNFLAG) {
		case UNUM32: offset += field_sizeof(union index_field, u32); break;
		case UNUM16: offset += field_sizeof(union index_field, u16); break;
		case UNUM64: offset += field_sizeof(union index_field, u64); break;
		case STRING: offset += field_sizeof(union index_field, str); break;
		}

		if (key_field->fieldno + 1 > d->min_tuple_cardinality)
			d->min_tuple_cardinality = key_field->fieldno + 1;
	}

	for (int i = d->cardinality-1; i > 0; i--)
		for (int j = 0; j < i; j++) {
			int inda = d->fill_order[j];
			int indb = d->fill_order[j+1];
			if (d->field_index[inda] > d->field_index[indb]) {
				d->fill_order[j+1] = inda;
				d->fill_order[j] = indb;
			}
		}

	return d;
}

#undef eq

register_source();
