import React from 'react';
import { Button } from '@/new-components/Button';
import { CardedTable } from '@/new-components/CardedTable';
import { IndicatorCard } from '@/new-components/IndicatorCard';
import { useTrackSelectedTables } from '../hooks/useTrackSelectedTables';
import { useCheckRows } from '../hooks/useCheckRows';
import { RenderTableRow } from './RenderTableRow';
import { TrackableTable } from '../types';

interface TrackTableProps {
  dataSourceName: string;
  tables: TrackableTable[];
}

export const TrackedTables = (props: TrackTableProps) => {
  const filteredTables = props.tables;

  const checkboxRef = React.useRef<HTMLInputElement>(null);
  const { checkedIds, onCheck, allChecked, toggleAll, reset, inputStatus } =
    useCheckRows(filteredTables || []);
  React.useEffect(() => {
    if (!checkboxRef.current) return;
    checkboxRef.current.indeterminate = inputStatus === 'indeterminate';
  }, [inputStatus]);

  const { unTrackSelectedTables } = useTrackSelectedTables(
    props.dataSourceName
  );

  const onClick = () => {
    unTrackSelectedTables(
      filteredTables.filter(({ name }) => checkedIds.includes(name))
    );
    reset();
  };

  if (!filteredTables.length) {
    return (
      <div className="space-y-4">
        <IndicatorCard>No tracked tables found</IndicatorCard>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="space-x-4">
        <Button mode="primary" disabled={!checkedIds.length} onClick={onClick}>
          Untrack Selected
        </Button>
      </div>
      <CardedTable.Table>
        <CardedTable.TableHead>
          <CardedTable.TableHeadRow>
            <th className="w-0 bg-gray-50 px-sm text-sm font-semibold text-muted uppercase tracking-wider border-r">
              <input
                ref={checkboxRef}
                type="checkbox"
                className="cursor-pointer
                rounded border shadow-sm border-gray-400 hover:border-gray-500 focus:ring-yellow-400"
                checked={allChecked}
                onChange={toggleAll}
              />
            </th>
            <CardedTable.TableHeadCell>Object</CardedTable.TableHeadCell>
            <CardedTable.TableHeadCell>Type</CardedTable.TableHeadCell>
            <CardedTable.TableHeadCell>Actions</CardedTable.TableHeadCell>
          </CardedTable.TableHeadRow>
        </CardedTable.TableHead>

        <CardedTable.TableBody>
          {filteredTables.map(table => {
            return (
              <RenderTableRow
                key={table.id}
                table={table}
                dataSourceName={props.dataSourceName}
                checked={checkedIds.includes(table.id)}
                reset={reset}
                onChange={() => onCheck(table.id)}
              />
            );
          })}
        </CardedTable.TableBody>
      </CardedTable.Table>
    </div>
  );
};
