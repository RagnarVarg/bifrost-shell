import QtQuick

// Bar widget content in a row that becomes a column on a side bar, each
// item centred across the bar. Children must not anchor themselves.
Grid {
    id: grid

    property bool vertical: false

    // Grid lays out as soon as rows or columns change, so switch through
    // 0/0 (automatic) and never through 1/1, which fits only one item.
    function apply() {
        if (vertical) {
            rows = 0;
            columns = 1;
        } else {
            columns = 0;
            rows = 1;
        }
    }

    rows: 1
    columns: 0
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    onVerticalChanged: apply()
    Component.onCompleted: apply()
}
