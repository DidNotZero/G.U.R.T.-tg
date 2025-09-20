import {
  Box,
  LabeledList,
  NoticeBox,
  Section,
  Table,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type BlackboardEntry = {
  key: string;
  summary: string;
  type: string;
  length?: number | null;
};

type ControllerEntry = {
  id: number;
  label: string;
  attach_reason: string;
  ai_status: string;
  tick_interval_ds: number;
  next_tick_time: number;
  mob_name: string | null;
  mob_ref: string | null;
  mob_stat: string | number | null;
  loc: string;
  blackboard: BlackboardEntry[];
};

type Data = {
  controllers: ControllerEntry[];
  updated_at: number;
};

type StaticData = {
  key_descriptions: Record<string, string>;
};

const formatTickInterval = (tickIntervalDs?: number) => {
  if (!tickIntervalDs) {
    return '—';
  }
  return `${(tickIntervalDs / 10).toFixed(1)}s`;
};

const formatMobStat = (stat?: string | number | null) => {
  if (stat === null || stat === undefined) {
    return '—';
  }
  return String(stat);
};

export const AICrewInspector = () => {
  const { data, staticData } = useBackend<Data, StaticData>();
  const controllers = data?.controllers ?? [];
  const keyDescriptions = staticData?.key_descriptions ?? {};

  return (
    <Window title="AI Crew Inspector" width={760} height={620} theme="admin">
      <Window.Content scrollable>
        {controllers.length === 0 ? (
          <NoticeBox>No AI Crew controllers are currently active.</NoticeBox>
        ) : (
          controllers.map((controller) => (
            <Section
              key={controller.id}
              title={`${controller.label} — ${controller.mob_name ?? 'No pawn attached'}`}
            >
              <LabeledList>
                <LabeledList.Item label="Mob">
                  {controller.mob_name ?? '—'}
                  {controller.mob_ref && (
                    <Box inline ml={1} color="label">
                      {controller.mob_ref}
                    </Box>
                  )}
                </LabeledList.Item>
                <LabeledList.Item label="Location">
                  {controller.loc ?? 'unknown'}
                </LabeledList.Item>
                <LabeledList.Item label="Mob Stat">
                  {formatMobStat(controller.mob_stat)}
                </LabeledList.Item>
                <LabeledList.Item label="AI Status">
                  {controller.ai_status ?? 'unknown'}
                </LabeledList.Item>
                <LabeledList.Item label="Tick Interval">
                  {formatTickInterval(controller.tick_interval_ds)}
                </LabeledList.Item>
                <LabeledList.Item label="Attach Reason">
                  {controller.attach_reason ?? '—'}
                </LabeledList.Item>
              </LabeledList>

              <Table mt={1} width="100%">
                <Table.Row header>
                  <Table.Cell collapsing>Key</Table.Cell>
                  <Table.Cell collapsing>Type</Table.Cell>
                  <Table.Cell collapsing>Len</Table.Cell>
                  <Table.Cell>Summary</Table.Cell>
                </Table.Row>
                {controller.blackboard?.length ? (
                  controller.blackboard.map((entry) => (
                    <Table.Row key={`${controller.id}-${entry.key}`}>
                      <Table.Cell collapsing>
                        <Box bold tooltip={keyDescriptions?.[entry.key]}>
                          {entry.key}
                        </Box>
                      </Table.Cell>
                      <Table.Cell collapsing>{entry.type}</Table.Cell>
                      <Table.Cell collapsing>
                        {entry.length === null || entry.length === undefined
                          ? '—'
                          : entry.length}
                      </Table.Cell>
                      <Table.Cell>
                        <Box whiteSpace="pre-wrap">{entry.summary}</Box>
                      </Table.Cell>
                    </Table.Row>
                  ))
                ) : (
                  <Table.Row>
                    <Table.Cell colSpan={4}>
                      <Box italic color="label">
                        No blackboard values recorded.
                      </Box>
                    </Table.Cell>
                  </Table.Row>
                )}
              </Table>
            </Section>
          ))
        )}
      </Window.Content>
    </Window>
  );
};
