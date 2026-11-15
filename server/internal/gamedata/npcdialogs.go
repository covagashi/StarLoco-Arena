package gamedata

import (
	"sort"
)

// NpcDialogReply is one reply row of an NPC dialog. Field order (atF.a v1):
//
//	[i16 textId]   reply label (retail text; ours are dlgr.<group>.<n>)
//	[i16 groupId]  the reply group ("node") this row belongs to
//	[i16 nextId]   group to open on click (0 = close the dialog)
//	[i16 order]    row ordering within the group
//	[i16 action]   1 = launch challenge, 2 = set criterion
//	[u8 n][i32×n]  action params (challenge id / criterion id)
//
// Clicking a reply runs its action then navigates to Next (ao_2 case 17001).
type NpcDialogReply struct {
	Group  int32
	Order  int32
	Next   int32
	Act    int32
	Params []int32
}

// NpcDialogs is every reply row, sorted by group then order.
type NpcDialogs struct {
	rows []*NpcDialogReply
}

// NewNpcDialogs builds the table from rows in any order.
func NewNpcDialogs(rows ...*NpcDialogReply) *NpcDialogs {
	d := &NpcDialogs{rows: append([]*NpcDialogReply(nil), rows...)}
	sort.SliceStable(d.rows, func(i, j int) bool {
		a, b := d.rows[i], d.rows[j]
		if a.Group != b.Group {
			return a.Group < b.Group
		}
		return a.Order < b.Order
	})
	return d
}

// Rows returns every reply row, sorted by group then order.
func (d *NpcDialogs) Rows() []*NpcDialogReply {
	if d == nil {
		return nil
	}
	return d.rows
}

// Len is the number of reply rows.
func (d *NpcDialogs) Len() int { return len(d.Rows()) }
