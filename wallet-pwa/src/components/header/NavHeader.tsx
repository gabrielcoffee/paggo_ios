import { ChevronLeft, CircleHelp, Info, Share } from 'lucide-react';

import { Button } from '@paggo/fend/components/atoms/button/button';
import { cn } from '@paggo/fend/utils';
import SemanticTypography from '@paggo/ui/components/atoms/semantic-typography';

type NavHeaderButtonIconType = 'back' | 'info' | 'help' | 'share';

type NavHeaderProps = {
  title?: string;
  leftButtonIconType?: NavHeaderButtonIconType;
  leftButtonTitle?: string;
  leftButtonPress?: () => void;
  rightButtonIconType?: NavHeaderButtonIconType;
  rightButtonTitle?: string | null;
  rightButtonPress?: () => void;
};

const getIconFromType = (type: NavHeaderButtonIconType | undefined) => {
  switch (type) {
    case 'back':
      return ChevronLeft;

    case 'help':
      return CircleHelp;

    case 'info':
      return Info;

    case 'share':
      return Share;

    default:
      return undefined;
  }
};

export default function NavHeader({
  leftButtonIconType,
  leftButtonPress,
  leftButtonTitle,
  rightButtonIconType,
  rightButtonPress,
  rightButtonTitle,
  title = '',
}: NavHeaderProps) {
  return (
    <div className="flex h-14 w-full justify-center">
      <div className="flex w-full items-center justify-center">
        <div
          className={cn('flex w-full items-center', !!rightButtonIconType && ' justify-between')}
        >
          {!!leftButtonIconType && (
            <div className="flex items-center">
              <Button
                hierarchy="tertiary"
                className="!stroke-white-pure shrink-0 !bg-transparent"
                icon={getIconFromType(leftButtonIconType)}
                onClick={leftButtonPress}
              />
              {leftButtonTitle && (
                <SemanticTypography.Label size="mid" color="white-pure">
                  {leftButtonTitle}
                </SemanticTypography.Label>
              )}
            </div>
          )}

          {title && (
            <SemanticTypography.Display size="small" color="white-pure" className="font-medium">
              {title}
            </SemanticTypography.Display>
          )}

          {!!rightButtonIconType && (
            <div className="flex items-center">
              {rightButtonTitle && (
                <SemanticTypography.Label size="mid" color="white-pure">
                  {rightButtonTitle}
                </SemanticTypography.Label>
              )}
              <Button
                hierarchy="tertiary"
                className="!stroke-white-pure shrink-0 !bg-transparent"
                icon={getIconFromType(rightButtonIconType)}
                onClick={rightButtonPress}
              />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
