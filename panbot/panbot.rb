class PanRunner
    attr_accessor :bot

    def getCurrentEpoch
    end

    def getCurrentPayout
    end

    def getCurrentAmount
    end

    def getCurrentBlock
    end

    def isLastBetable
    end

    def betBull(sender,amount)
    end

    def betBear(sender,amount)
    end

    def endRound()
    end

    def log(str)
    end

    def run
    end

    def initialize()
        @bot=[]
    end 
end

class PanBot
    attr_accessor :runner
    attr_accessor :epoch_bet
    attr_accessor :bet_result

    def initialize(runner)
        @runner = runner
        @runner.bot.push(self)
        @bet_result = []
    end 

    def mainLoop
    end

    def method_missing(m, *args)
        return @runner.send(m) if args==[]
        return @runner.send(m,*args) if args!=[]
    end
end


class SimulationRunner < PanRunner
    attr_accessor :block, :block_end, :epoch, :logs

    def initialize()
        @logs = []
        super
    end 

    def log(str)
        @logs.push str
    end

    def getEpoch
        if @epoch==nil or @block > @epoch.lock_block_number then
            @epoch = Block.find_by_block_number(@block).ar_epoch
        end
        if @epoch==nil then
            @block = Epoch.find_by_epoch(Block.find_by_block_number(@block-1).ar_epoch.epoch+1).start_block_number            
            @epoch = Block.find_by_block_number(@block).ar_epoch
        end
        return @epoch
    end

    def run
        while @block<=@block_end do
            @bot.each do |b|
                b.mainLoop
            end
            @block = @block + 1

            ar_epoch = getEpoch
            endRound() if ar_epoch.lock_block_number == @block
        end
    end

    def time_at_epoch(begin_epoch,end_epoch)
        @block = Epoch.find_by_epoch(begin_epoch).start_block_number
        @block_end = Epoch.find_by_epoch(end_epoch).lock_block_number
    end

    def time_at_block(begin_block,end_block)
        @block = begin_block
        @block_end = end_block
    end

    def lastBlockOrder
        ar_epoch = getEpoch
        return ar_epoch.lock_block_number - block
    end

    def isLastBetable
        lastBlockOrder == 3
    end

    def getCurrentEpoch
        getEpoch.epoch
    end

    def getCurrentBlock
        @block
    end

    def getCurrentPayout
        ar_epoch = getEpoch
        return ar_epoch.get_bull_payout(@block),ar_epoch.get_bear_payout(@block),ar_epoch.get_bull_amount(@block),ar_epoch.get_bear_amount(@block)
    end

    def getCurrentAmount
        ar_epoch = getEpoch
        return ar_epoch.get_amount(@block)
    end

    def betBull(sender,amount)
        log "===betBull #{amount}==="
        sender.epoch_bet = ["bull",amount,lastBlockOrder-2] if sender.epoch_bet==nil
    end

    def betBear(sender,amount)
        log "===betBear #{amount}==="
        sender.epoch_bet = ["bear",amount,lastBlockOrder-2] if sender.epoch_bet==nil
    end

    def endRound()
        ar_epoch = getEpoch

        puts "#{Time.now} - #{ar_epoch.epoch}" if ar_epoch.epoch % 1000 ==0

        @block = ar_epoch.lock_block_number
        log "===endRound #{ar_epoch.epoch}==="

        log "===origin #{ar_epoch.bet_result} #{getCurrentPayout} ==="
        _, _, amount_bull, amount_bear = getCurrentPayout
        
        @bot.each do |b|
            next if b.epoch_bet==nil
            if b.epoch_bet[0]=="bull" then
                amount_bull = amount_bull + b.epoch_bet[1]
            end
            if b.epoch_bet[0]=="bear" then
                amount_bear = amount_bear + b.epoch_bet[1]
            end
        end

        total_amount = amount_bull+amount_bear
        log "===new #{ar_epoch.bet_result} #{[total_amount/amount_bull, total_amount/amount_bear, amount_bull,amount_bear]}==="


        @bot.each do |b|
            if b.epoch_bet then
                round = {:epoch=>ar_epoch.epoch, :bet=>b.epoch_bet[0],:amount=>b.epoch_bet[1],:bet_block_order=>b.epoch_bet[2],
                        :bull_payout=>total_amount/amount_bull, :bear_payout=>total_amount/amount_bear, 
                        :bull_amount=>amount_bull, :bear_amount=>amount_bear, :bet_result=>ar_epoch.bet_result
                        }
                b.bet_result.push round
                b.epoch_bet = nil
            else
                round = {:epoch=>ar_epoch.epoch, :bet=>"",:amount=>nil,:bet_block_order=>nil,
                        :bull_payout=>total_amount/amount_bull, :bear_payout=>total_amount/amount_bear, 
                        :bull_amount=>amount_bull, :bear_amount=>amount_bear, :bet_result=>ar_epoch.bet_result
                        }
                b.bet_result.push round
            end
        end
    end

end

