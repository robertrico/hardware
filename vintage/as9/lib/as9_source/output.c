/*
 *  stable --- prints the symbol table in alphabetical order
 */
void stable(struct nlist *ptr)
{
  if (ptr != NULL)
    {
      stable (ptr->Lnext);
        fprintf (Symfil,"%-10s %04x\n",ptr->name,ptr->def);
      stable (ptr->Rnext);
    }
}
/*
 *  cross  --  prints the cross reference table
 */
void cross(struct nlist *point)
{
struct link *tp;
int i = 1;
  if (point != NULL)
    {
      cross (point->Lnext);
        fprintf (Crffil,"%-10s %04x *",point->name,point->def);
         tp = point->L_list;
          while (tp != NULL)
           {
             if (i++>10)
              {
               i=1;
               fprintf(Crffil,"\n                      ");
              }
              fprintf (Crffil,"%04d ",tp->L_num);
               tp = tp->next;
           }
         fprintf (Crffil,"\n");
      cross (point->Rnext);
    }
}
