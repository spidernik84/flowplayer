import QtQuick 2.0
import Sailfish.Silica 1.0

// A SilicaListView whose rows can be selected and reordered while `editing`
// is true. The model must be a ListModel, and all rows rowHeight tall.
// A delegate starts a drag from its handle with startDrag(), then forwards
// finger moves to updateDrag() and the release to endDrag(). Dragging a
// selected row gathers the other selected rows around it and moves them all.
SilicaListView {
    id: view

    property bool editing: false
    property var selection: []          // selection[i] is true when row i is selected
    property int selectedCount: 0
    property real rowHeight: Theme.itemSizeSmall

    // Drag state. fingerY is in view coordinates.
    // Not "dragging": that would hide Flickable.dragging, which the
    // pull-down menu reads to pick the item under the finger
    property bool reordering: false
    property int dragIndex: -1          // first row of the dragged block
    property int dragCount: 0
    property int grabOffset: 0          // grabbed row, counted from dragIndex
    property real grabY: 0              // finger position inside the grabbed row
    property real fingerY: 0
    property real firstRowY: 0          // y of row 0 in content coordinates
    property bool dragMoved: false

    // Emitted when a drag starts, before any row moves
    signal reorderStarted()
    // Emitted after the user changed the row order
    signal reordered()

    interactive: !reordering

    onEditingChanged: {
        endDrag()
        clearSelection()
    }

    onCountChanged: {
        if (!reordering)
            clearSelection()
    }

    move: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.InOutQuad } }
    moveDisplaced: Transition { NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.InOutQuad } }

    function isSelected(i) {
        return selection[i] === true
    }

    function setSelected(i, on) {
        var sel = selection.slice()
        sel[i] = on
        selection = sel
        selectedCount = selectedIndices().length
    }

    function toggleSelected(i) {
        setSelected(i, !isSelected(i))
    }

    function selectAll() {
        var sel = []
        for (var i=0; i<count; ++i)
            sel.push(true)
        selection = sel
        selectedCount = count
    }

    function setSelection(sel) {
        selection = sel.slice()
        selectedCount = selectedIndices().length
    }

    function clearSelection() {
        selection = []
        selectedCount = 0
    }

    function selectedIndices() {
        var rows = []
        for (var i=0; i<count; ++i)
            if (isSelected(i)) rows.push(i)
        return rows
    }

    // Moves n rows, and their selection with them
    function moveRows(from, to, n) {
        if (from===to || n<1)
            return
        model.move(from, to, n)
        var sel = []
        for (var i=0; i<count; ++i)
            sel.push(isSelected(i))
        var moved = sel.splice(from, n)
        for (i=0; i<n; ++i)
            sel.splice(to+i, 0, moved[i])
        selection = sel
    }

    // Reorders the rows so that the row now at order[i] ends up at i.
    // Rows are placed from the top, so each move only shifts unplaced rows.
    function applyOrder(order) {
        var current = []
        for (var i=0; i<order.length; ++i)
            current.push(i)
        for (var p=0; p<order.length; ++p) {
            var q = current.indexOf(order[p])
            if (q!==p) {
                moveRows(q, p, 1)
                current.splice(p, 0, current.splice(q, 1)[0])
            }
        }
    }

    // Gathers the selected rows, in order, into one block that starts at
    // `position`, counted in the list without the selected rows
    function moveSelectionTo(position) {
        var rest = [], sel = []
        for (var i=0; i<count; ++i)
            (isSelected(i) ? sel : rest).push(i)
        applyOrder(rest.slice(0, position).concat(sel, rest.slice(position)))
    }

    // item is the grabbed delegate, y the finger position in view coordinates
    function startDrag(item, index, y) {
        if (!editing || reordering)
            return

        reorderStarted()
        firstRowY = item.y - index*rowHeight
        var before = selectionPattern()
        if (isSelected(index) && selectedCount>1) {
            var above = 0, selectedAbove = 0
            for (var i=0; i<index; ++i) {
                if (isSelected(i)) selectedAbove++
                else above++
            }
            moveSelectionTo(above)
            dragIndex = above
            dragCount = selectedCount
            grabOffset = selectedAbove
        } else {
            dragIndex = index
            dragCount = 1
            grabOffset = 0
        }
        dragMoved = selectionPattern()!==before

        grabY = contentY + y - (firstRowY + (dragIndex+grabOffset)*rowHeight)
        fingerY = y
        reordering = true
    }

    function updateDrag(y) {
        if (!reordering)
            return
        fingerY = y
        var center = contentY + y - grabY + rowHeight/2 - firstRowY
        var row = Math.floor(center/rowHeight)
        var to = Math.max(0, Math.min(count-dragCount, row-grabOffset))
        if (to!==dragIndex) {
            moveRows(dragIndex, to, dragCount)
            dragIndex = to
            dragMoved = true
        }
    }

    function endDrag() {
        if (!reordering)
            return
        reordering = false
        dragIndex = -1
        dragCount = 0
        if (dragMoved)
            reordered()
        dragMoved = false
    }

    function isDragged(i) {
        return reordering && i>=dragIndex && i<dragIndex+dragCount
    }

    // Where the selected rows are, to tell whether gathering them moved any
    function selectionPattern() {
        var s = ""
        for (var i=0; i<count; ++i)
            s += isSelected(i) ? "1" : "0"
        return s
    }

    // Scrolls while the dragged row is held near the top or bottom edge
    Timer {
        interval: 16
        repeat: true
        running: view.reordering && (view.fingerY < view.rowHeight || view.fingerY > view.height - view.rowHeight)
        onTriggered: {
            var step = view.rowHeight / 6
            var top = view.originY
            var bottom = Math.max(top, view.originY + view.contentHeight - view.height)
            if (view.fingerY < view.rowHeight)
                view.contentY = Math.max(top, view.contentY - step)
            else
                view.contentY = Math.min(bottom, view.contentY + step)
            view.updateDrag(view.fingerY)
        }
    }
}
