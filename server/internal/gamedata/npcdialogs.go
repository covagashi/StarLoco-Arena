package gamedata

import (
	"encoding/binary"
	"sort"
)

// TypeNpcDialogReply is the data.bdat record type of NPC dialog reply rows
// (client `atF`).
const TypeNpcDialogReply = 1500

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

// LoadNpcDialogs decodes every type-1500 row; short rows are skipped.
func (s *Store) LoadNpcDialogs() (*NpcDialogs, error) {
	var rows []*NpcDialogReply
	for _, e := range s.EntriesOf(TypeNpcDialogReply) {
		rec, err := s.ReadRecord(e.Position)
		if err != nil {
			return nil, err
		}
		if r := decodeNpcDialogReply(rec.Data); r != nil {
			rows = append(rows, r)
		}
	}
	return NewNpcDialogs(rows...), nil
}

func decodeNpcDialogReply(d []byte) *NpcDialogReply {
	if len(d) < 11 {
		return nil
	}
	f := make([]int32, 5)
	for i := range f {
		f[i] = int32(int16(binary.BigEndian.Uint16(d[i*2:])))
	}
	n := int(d[10])
	if len(d) < 11+4*n {
		return nil
	}
	var params []int32
	for i := 0; i < n; i++ {
		params = append(params, int32(binary.BigEndian.Uint32(d[11+i*4:])))
	}
	return &NpcDialogReply{Group: f[1], Next: f[2], Order: f[3], Act: f[4], Params: params}
}
