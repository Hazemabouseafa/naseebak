<x-filament-panels::page>
    <form wire:submit="save" class="space-y-6" dir="rtl">
        {{ $this->form }}
        <div class="flex flex-wrap gap-3">
            <x-filament::button type="submit" color="primary">
                تأكيد وتفعيل بوابة الدفع المختارة
            </x-filament::button>
            <x-filament::button type="button" color="gray" wire:click="checkReadiness">
                فحص جاهزية الربط الآن
            </x-filament::button>
        </div>
    </form>
</x-filament-panels::page>
